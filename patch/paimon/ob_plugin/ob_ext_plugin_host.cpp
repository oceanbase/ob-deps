// Copyright 2024-present Alibaba Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "ob_ext_plugin_host.h"

#include "paimon/executor.h"
#include "paimon/fs/file_system.h"
#include "paimon/memory/memory_pool.h"
#include "paimon/status.h"

#include <cstddef>
#include <cstdint>
#include <functional>
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace ob_ext_paimon {
namespace {

class ObHostMemoryPool final : public paimon::MemoryPool {
 public:
  explicit ObHostMemoryPool(const ObExtTableHostApi* host) : host_(host) {}

  void* Malloc(uint64_t size, uint64_t alignment = 0) override
  {
    // Pass the plugin's requested alignment straight through to the host pool,
    // which does ob_malloc_align(alignment, size, ...) — no manual over-
    // allocation prefix here. The host pool owns alignment + the arrow zero-size
    // placeholder canary; the plugin just routes the call.
    if (host_ == nullptr || host_->mem.mem_alloc == nullptr) {
      return nullptr;
    }
    return host_->mem.mem_alloc(host_->ctx, static_cast<int64_t>(size),
                                 static_cast<int64_t>(alignment));
  }

  void* Realloc(void* ptr, size_t old_size, size_t new_size, uint64_t alignment = 0) override
  {
    if (ptr == nullptr) {
      return Malloc(new_size, alignment);
    }
    if (host_ == nullptr || host_->mem.mem_realloc == nullptr) {
      return nullptr;
    }
    return host_->mem.mem_realloc(host_->ctx, ptr,
                                   static_cast<int64_t>(old_size),
                                   static_cast<int64_t>(new_size),
                                   static_cast<int64_t>(alignment));
  }

  void Free(void* ptr, uint64_t size) override
  {
    if (ptr != nullptr && host_ != nullptr && host_->mem.mem_free != nullptr) {
      host_->mem.mem_free(host_->ctx, ptr, static_cast<int64_t>(size));
    }
  }

  void Free(void* ptr, uint64_t size, uint64_t /*alignment*/) override
  {
    // The host frees by pointer (ob_free_align), so the alignment arg is not
    // needed here — delegate to the size-only Free.
    Free(ptr, size);
  }

  uint64_t CurrentUsage() const override
  {
    if (host_ != nullptr && host_->mem.mem_bytes_allocated != nullptr) {
      const int64_t usage = host_->mem.mem_bytes_allocated(host_->ctx);
      return usage > 0 ? static_cast<uint64_t>(usage) : 0;
    }
    return 0;
  }

  uint64_t MaxMemoryUsage() const override { return CurrentUsage(); }

 private:
  const ObExtTableHostApi* host_;
};

class ObHostExecutor final : public paimon::Executor {
 public:
  explicit ObHostExecutor(const ObExtTableHostApi* host) : host_(host) {}
  ~ObHostExecutor() override = default;

  void Add(std::function<void()> func) override
  {
    if (host_ == nullptr || host_->executor.exec_submit == nullptr) {
      func();
      return;
    }
    auto* task = new std::function<void()>(std::move(func));
    const int32_t rc = host_->executor.exec_submit(host_->ctx,
        [](void* arg) {
          std::unique_ptr<std::function<void()>> fn(static_cast<std::function<void()>*>(arg));
          (*fn)();
        },
        task);
    if (rc != 0) {
      // The host REJECTED the task without taking ownership (contract:
      // exec_submit returns an OB errno). Reclaim it here — running inline —
      // otherwise the heap std::function would leak.
      OBEXT_LOG_WARN(host_, "host exec_submit rejected task, rc=%d; run inline", (int)rc);
      std::unique_ptr<std::function<void()>> fn(task);
      (*fn)();
    }
  }

  void ShutdownNow() override {}

 private:
  const ObExtTableHostApi* host_;
};

class ObHostInputStream final : public paimon::InputStream {
 public:
  ObHostInputStream(const ObExtTableHostApi* host, void* stream)
      : host_(host), stream_(stream)
  {}

  ~ObHostInputStream() override { (void)Close(); }

  paimon::Status Seek(int64_t offset, paimon::SeekOrigin origin) override
  {
    if (closed_) {
      return paimon::Status::IOError("stream is closed");
    }
    if (host_ == nullptr || host_->io.file_seek == nullptr) {
      return paimon::Status::NotImplemented("host file_seek missing");
    }
    int32_t ob_origin = OB_EXT_SEEK_SET;
    if (origin == paimon::FS_SEEK_CUR) {
      ob_origin = OB_EXT_SEEK_CUR;
    } else if (origin == paimon::FS_SEEK_END) {
      ob_origin = OB_EXT_SEEK_END;
    }
    if (host_->io.file_seek(host_->ctx, stream_, offset, ob_origin) != 0) {
      return paimon::Status::IOError("host file_seek failed");
    }
    return paimon::Status::OK();
  }

  paimon::Result<int64_t> GetPos() const override
  {
    if (closed_) {
      return paimon::Status::IOError("stream is closed");
    }
    if (host_ == nullptr || host_->io.file_tell == nullptr) {
      return paimon::Status::NotImplemented("host file_tell missing");
    }
    const int64_t pos = host_->io.file_tell(host_->ctx, stream_);
    if (pos < 0) {
      return paimon::Status::IOError("host file_tell failed");
    }
    return pos;
  }

  paimon::Result<int32_t> Read(char* buffer, uint32_t size) override
  {
    if (closed_) {
      return paimon::Status::IOError("stream is closed");
    }
    if (host_ == nullptr || host_->io.file_read == nullptr) {
      return paimon::Status::NotImplemented("host file_read missing");
    }
    const int64_t n = host_->io.file_read(host_->ctx, stream_, buffer, size);
    if (n < 0 || n > std::numeric_limits<int32_t>::max()) {
      return paimon::Status::IOError("host file_read failed");
    }
    return static_cast<int32_t>(n);
  }

  paimon::Result<int32_t> Read(char* buffer, uint32_t size, uint64_t offset) override
  {
    if (closed_) {
      return paimon::Status::IOError("stream is closed");
    }
    if (offset > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
      return paimon::Status::Invalid("read offset is too large");
    }
    if (host_ != nullptr && host_->io.file_read_at != nullptr) {
      const int64_t n = host_->io.file_read_at(host_->ctx, stream_, buffer, size,
                                           static_cast<int64_t>(offset));
      if (n < 0 || n > std::numeric_limits<int32_t>::max()) {
        return paimon::Status::IOError("host file_read_at failed");
      }
      return static_cast<int32_t>(n);
    }
    const auto saved = GetPos();
    if (!saved.ok()) {
      return saved.status();
    }
    paimon::Status st = Seek(static_cast<int64_t>(offset), paimon::FS_SEEK_SET);
    if (!st.ok()) {
      return st;
    }
    auto n = Read(buffer, size);
    paimon::Status restore_st = Seek(saved.value(), paimon::FS_SEEK_SET);
    if (n.ok() && !restore_st.ok()) {
      // The data was read but the stream position could not be restored —
      // returning success here would leave every later sequential read at a
      // wrong offset. Surface the restore failure instead of swallowing it.
      return restore_st;
    }
    return n;
  }

  void ReadAsync(char* buffer, uint32_t size, uint64_t offset,
                 std::function<void(paimon::Status)>&& callback) override
  {
    auto n = Read(buffer, size, offset);
    callback(n.ok() ? paimon::Status::OK() : n.status());
  }

  paimon::Result<std::string> GetUri() const override { return std::string(); }

  paimon::Result<uint64_t> Length() const override
  {
    if (closed_) {
      return paimon::Status::IOError("stream is closed");
    }
    if (host_ == nullptr || host_->io.file_length == nullptr) {
      return paimon::Status::NotImplemented("host file_length missing");
    }
    const int64_t len = host_->io.file_length(host_->ctx, stream_);
    if (len < 0) {
      return paimon::Status::IOError("host file_length failed");
    }
    return static_cast<uint64_t>(len);
  }

  paimon::Status Close() override
  {
    if (!closed_ && stream_ != nullptr && host_ != nullptr && host_->io.file_close != nullptr) {
      host_->io.file_close(host_->ctx, stream_);
    }
    stream_ = nullptr;
    closed_ = true;
    return paimon::Status::OK();
  }

 private:
  const ObExtTableHostApi* host_;
  void* stream_;
  bool closed_ = false;
};

class ObHostFileStatus final : public paimon::FileStatus {
 public:
  ObHostFileStatus(std::string path, uint64_t len, int64_t mod_time, bool is_dir)
      : path_(std::move(path)), len_(len), mod_time_(mod_time), is_dir_(is_dir)
  {}

  uint64_t GetLen() const override { return len_; }
  bool IsDir() const override { return is_dir_; }
  std::string GetPath() const override { return path_; }
  int64_t GetModificationTime() const override { return mod_time_; }

 private:
  std::string path_;
  uint64_t len_;
  int64_t mod_time_;
  bool is_dir_;
};

// Lightweight BasicFileStatus (path + IsDir) for ListDir — paimon's ListDir only
// needs IsDir() and GetPath(); the path's basename is what ListVersionedFiles
// extracts via PathUtil::GetName, so we store the joined "dir/name" path.
class ObHostBasicFileStatus final : public paimon::BasicFileStatus {
 public:
  ObHostBasicFileStatus(std::string path, bool is_dir)
      : path_(std::move(path)), is_dir_(is_dir)
  {}

  bool IsDir() const override { return is_dir_; }
  std::string GetPath() const override { return path_; }

 private:
  std::string path_;
  bool is_dir_;
};

class ObHostFileSystem final : public paimon::FileSystem {
 public:
  explicit ObHostFileSystem(const ObExtTableHostApi* host) : host_(host) {}

  paimon::Result<std::unique_ptr<paimon::InputStream>> Open(const std::string& path) const override
  {
    if (host_ == nullptr || host_->io.file_open == nullptr) {
      return paimon::Status::NotImplemented("host file_open missing");
    }
    void* stream = host_->io.file_open(host_->ctx, path.c_str());
    if (stream == nullptr) {
      return paimon::Status::IOError("host file_open failed: ", path);
    }
    return std::unique_ptr<paimon::InputStream>(new ObHostInputStream(host_, stream));
  }

  paimon::Result<std::unique_ptr<paimon::OutputStream>> Create(
      const std::string&, bool) const override
  {
    return paimon::Status::NotImplemented("OB external-table host is read-only");
  }

  paimon::Status Mkdirs(const std::string&) const override
  {
    return paimon::Status::NotImplemented("OB external-table host is read-only");
  }

  paimon::Status Rename(const std::string&, const std::string&) const override
  {
    return paimon::Status::NotImplemented("OB external-table host is read-only");
  }

  paimon::Status Delete(const std::string&, bool = true) const override
  {
    return paimon::Status::NotImplemented("OB external-table host is read-only");
  }

  paimon::Result<std::unique_ptr<paimon::FileStatus>> GetFileStatus(
      const std::string& path) const override
  {
    paimon::Status st = paimon::Status::OK();
    std::unique_ptr<paimon::FileStatus> file_status;
    if (host_ == nullptr || host_->io.file_status == nullptr) {
      st = paimon::Status::NotImplemented("host file_status missing");
    } else {
      int64_t size = -1;
      int64_t mod_time = -1;
      int32_t is_dir = 0;
      const int32_t rc =
          host_->io.file_status(host_->ctx, path.c_str(), &size, &mod_time, &is_dir);
      if (rc != 0) {
        st = paimon::Status::IOError("host file_status failed, rc=", std::to_string(rc));
      } else if (size < 0 || mod_time < 0 || (is_dir != 0 && is_dir != 1)) {
        st = paimon::Status::IOError("host file_status returned invalid metadata");
      } else {
        file_status = std::make_unique<ObHostFileStatus>(
            path, static_cast<uint64_t>(size), mod_time, is_dir != 0);
      }
    }
    if (st.ok()) {
      return std::move(file_status);
    }
    return st;
  }

  paimon::Status ListDir(
      const std::string& dir,
      std::vector<std::unique_ptr<paimon::BasicFileStatus>>* out) const override
  {
    if (out == nullptr) {
      return paimon::Status::Invalid("ListDir out is null");
    }
    if (host_ == nullptr || host_->io.list_dir == nullptr) {
      return paimon::Status::NotImplemented("host list_dir missing");
    }
    // The host list_dir contract returns OK with zero callbacks for an empty
    // or non-existent directory; versioned-file callers keep their own guard.
    // The host streams (basename, is_dir) pairs via cb; we build BasicFileStatus
    // with joined "dir/name" paths so paimon's PathUtil::GetName extracts the
    // basename on its side.
    struct Ctx {
      const std::string* dir;
      std::vector<std::unique_ptr<paimon::BasicFileStatus>>* out;
    } ctx{&dir, out};
    auto cb = [](void* c, const char* name, int32_t is_dir) {
      auto* x = static_cast<Ctx*>(c);
      std::string full = *x->dir;
      if (!full.empty() && full.back() != '/') {
        full.push_back('/');
      }
      if (name != nullptr) {
        full.append(name);
      }
      x->out->push_back(std::unique_ptr<paimon::BasicFileStatus>(
          new ObHostBasicFileStatus(std::move(full), is_dir != 0)));
    };
    const int32_t rc = host_->io.list_dir(host_->ctx, dir.c_str(), cb, &ctx);
    if (rc != 0) {
      return paimon::Status::IOError("host list_dir failed, rc=", std::to_string(rc));
    }
    return paimon::Status::OK();
  }

  paimon::Status ListFileStatus(
      const std::string&,
      std::vector<std::unique_ptr<paimon::FileStatus>>*) const override
  {
    return paimon::Status::NotImplemented("host ListFileStatus missing");
  }

  paimon::Result<bool> Exists(const std::string& path) const override
  {
    paimon::Result<bool> result = false;
    if (host_ != nullptr && host_->io.file_exists != nullptr) {
      const int32_t rc = host_->io.file_exists(host_->ctx, path.c_str());
      if (rc < 0) {
        result = paimon::Status::IOError("host file_exists failed: ", path);
      } else {
        result = rc == 1;
      }
    } else {
      auto stream = Open(path);
      result = stream.ok();
    }
    return result;
  }

  paimon::Status ReadFile(const std::string& path, std::string* content) override
  {
    paimon::Status st = paimon::Status::OK();
    if (content == nullptr) {
      st = paimon::Status::Invalid("content is null");
    }
    if (st.ok()) {
      auto stream = Open(path);
      if (!stream.ok()) {
        st = stream.status();
      } else {
        auto len = stream.value()->Length();
        if (!len.ok()) {
          st = len.status();
        } else {
          content->resize(static_cast<size_t>(len.value()));
          if (!content->empty()) {
            auto n = stream.value()->Read(&(*content)[0],
                                          static_cast<uint32_t>(content->size()));
            if (!n.ok()) {
              st = n.status();
            } else {
              content->resize(static_cast<size_t>(n.value()));
            }
          }
        }
      }
    }
    return st;
  }

 private:
  const ObExtTableHostApi* host_;
};

}  // namespace

std::shared_ptr<paimon::MemoryPool> make_memory_pool(const ObExtTableHostApi* host)
{
  return host == nullptr ? nullptr : std::make_shared<ObHostMemoryPool>(host);
}

std::shared_ptr<paimon::Executor> make_executor(const ObExtTableHostApi* host)
{
  return host == nullptr ? nullptr : std::make_shared<ObHostExecutor>(host);
}

std::shared_ptr<paimon::FileSystem> make_file_system(
    const ObExtTableHostApi* host, std::shared_ptr<paimon::Executor> /*executor*/)
{
  return host == nullptr ? nullptr : std::make_shared<ObHostFileSystem>(host);
}

}  // namespace ob_ext_paimon
