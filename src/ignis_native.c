#define _GNU_SOURCE
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

typedef struct lua_State lua_State;
typedef int (*lua_CFunction)(lua_State *L);
typedef ptrdiff_t lua_Integer;
typedef double lua_Number;

#define LUA_TNONE          (-1)
#define LUA_TNIL           0
#define LUA_TBOOLEAN       1
#define LUA_TLIGHTUSERDATA 2
#define LUA_TNUMBER        3
#define LUA_TSTRING        4
#define LUA_TTABLE         5
#define LUA_TFUNCTION      6
#define LUA_TUSERDATA      7
#define LUA_TTHREAD        8

static int         (*p_lua_gettop)(lua_State *L);
static void        (*p_lua_settop)(lua_State *L, int idx);
static int         (*p_lua_type)(lua_State *L, int idx);
static void        (*p_lua_pushnil)(lua_State *L);
static void        (*p_lua_pushboolean)(lua_State *L, int b);
static void        (*p_lua_pushinteger)(lua_State *L, lua_Integer n);
static void        (*p_lua_pushnumber)(lua_State *L, lua_Number n);
static const char *(*p_lua_pushlstring)(lua_State *L, const char *s, size_t len);
static const char *(*p_lua_pushstring)(lua_State *L, const char *s);
static void        (*p_lua_pushcclosure)(lua_State *L, lua_CFunction fn, int n);
static void        (*p_lua_createtable)(lua_State *L, int narr, int nrec);
static void        (*p_lua_setfield)(lua_State *L, int idx, const char *k);
static int         (*p_lua_rawgetp)(lua_State *L, int idx, const void *p);
static void        (*p_lua_rawget)(lua_State *L, int idx);
static void        (*p_lua_pushlightuserdata)(lua_State *L, void *p);
static const char *(*p_lua_tolstring)(lua_State *L, int idx, size_t *len);
static lua_Integer (*p_lua_tointegerx)(lua_State *L, int idx, int *isnum);
static lua_Integer (*p_lua_tointeger)(lua_State *L, int idx);

static int api_resolved = 0;

static int resolve_lua_api(void) {
    if (api_resolved) return 1;

    #define LOAD_SYM(name) \
        p_##name = dlsym(RTLD_DEFAULT, #name)

    LOAD_SYM(lua_gettop);
    LOAD_SYM(lua_settop);
    LOAD_SYM(lua_type);
    LOAD_SYM(lua_pushnil);
    LOAD_SYM(lua_pushboolean);
    LOAD_SYM(lua_pushinteger);
    LOAD_SYM(lua_pushnumber);
    LOAD_SYM(lua_pushlstring);
    LOAD_SYM(lua_pushstring);
    LOAD_SYM(lua_pushcclosure);
    LOAD_SYM(lua_createtable);
    LOAD_SYM(lua_setfield);
    LOAD_SYM(lua_rawgetp);
    LOAD_SYM(lua_rawget);
    LOAD_SYM(lua_pushlightuserdata);
    LOAD_SYM(lua_tolstring);
    LOAD_SYM(lua_tointegerx);
    LOAD_SYM(lua_tointeger);

    #undef LOAD_SYM

    if (!p_lua_gettop || !p_lua_settop || !p_lua_type || !p_lua_pushnil ||
        !p_lua_pushcclosure || !p_lua_createtable || !p_lua_setfield ||
        !p_lua_tolstring) {
        return 0;
    }

    api_resolved = 1;
    return 1;
}

static lua_Integer get_integer(lua_State *L, int idx, lua_Integer def) {
    if (p_lua_type(L, idx) != LUA_TNUMBER) return def;
    if (p_lua_tointegerx) {
        int isnum = 0;
        lua_Integer v = p_lua_tointegerx(L, idx, &isnum);
        return isnum ? v : def;
    }
    if (p_lua_tointeger) {
        return p_lua_tointeger(L, idx);
    }
    return def;
}

static int l_get_self(lua_State *L) {
    if (p_lua_gettop(L) < 2 || p_lua_type(L, 1) != LUA_TTABLE) {
        p_lua_pushnil(L);
        return 1;
    }
    p_lua_settop(L, 2);
    p_lua_rawget(L, 1);
    return 1;
}

static int l_read_file(lua_State *L) {
    size_t path_len = 0;
    const char *path = p_lua_tolstring(L, 1, &path_len);
    if (!path || path_len == 0) {
        p_lua_pushnil(L);
        p_lua_pushstring(L, "invalid path");
        return 2;
    }

    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        p_lua_pushnil(L);
        p_lua_pushstring(L, strerror(errno));
        return 2;
    }

    struct stat st;
    if (fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && st.st_size > 0 && st.st_size <= (64 * 1024 * 1024)) {
        size_t size = (size_t)st.st_size;
        char stack_buf[16384];
        char *buf = (size <= sizeof(stack_buf)) ? stack_buf : (char *)malloc(size);
        if (!buf) {
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, "out of memory");
            return 2;
        }
        size_t total = 0;
        while (total < size) {
            ssize_t r = read(fd, buf + total, size - total);
            if (r < 0) {
                if (errno == EINTR) continue;
                break;
            }
            if (r == 0) break;
            total += (size_t)r;
        }
        close(fd);
        p_lua_pushlstring(L, buf, total);
        if (buf != stack_buf) free(buf);
        return 1;
    }

    char stack_buf[16384];
    ssize_t first_r = read(fd, stack_buf, sizeof(stack_buf));
    if (first_r >= 0 && (size_t)first_r < sizeof(stack_buf)) {
        close(fd);
        p_lua_pushlstring(L, stack_buf, (size_t)first_r);
        return 1;
    }

    size_t cap = 32768;
    size_t len = (first_r > 0) ? (size_t)first_r : 0;
    char *buf = (char *)malloc(cap);
    if (!buf) {
        close(fd);
        p_lua_pushnil(L);
        p_lua_pushstring(L, "out of memory");
        return 2;
    }
    if (len > 0) memcpy(buf, stack_buf, len);

    for (;;) {
        if (len == cap) {
            size_t new_cap = cap * 2;
            char *new_buf = (char *)realloc(buf, new_cap);
            if (!new_buf) {
                free(buf);
                close(fd);
                p_lua_pushnil(L);
                p_lua_pushstring(L, "out of memory");
                return 2;
            }
            buf = new_buf;
            cap = new_cap;
        }
        ssize_t r = read(fd, buf + len, cap - len);
        if (r < 0) {
            if (errno == EINTR) continue;
            free(buf);
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, strerror(errno));
            return 2;
        }
        if (r == 0) break;
        len += (size_t)r;
    }

    close(fd);
    p_lua_pushlstring(L, buf, len);
    free(buf);
    return 1;
}

static int l_write_file(lua_State *L) {
    size_t path_len = 0, data_len = 0;
    const char *path = p_lua_tolstring(L, 1, &path_len);
    const char *data = p_lua_tolstring(L, 2, &data_len);
    if (!path || path_len == 0 || !data) {
        p_lua_pushboolean(L, 0);
        p_lua_pushstring(L, "invalid arguments");
        return 2;
    }

    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) {
        p_lua_pushboolean(L, 0);
        p_lua_pushstring(L, strerror(errno));
        return 2;
    }

    size_t written = 0;
    while (written < data_len) {
        ssize_t w = write(fd, data + written, data_len - written);
        if (w < 0) {
            if (errno == EINTR) continue;
            int err = errno;
            close(fd);
            p_lua_pushboolean(L, 0);
            p_lua_pushstring(L, strerror(err));
            return 2;
        }
        written += (size_t)w;
    }

    close(fd);
    p_lua_pushboolean(L, 1);
    return 1;
}

static int l_unix_request(lua_State *L) {
    size_t path_len = 0, req_len = 0;
    const char *sock_path = p_lua_tolstring(L, 1, &path_len);
    const char *req_data  = p_lua_tolstring(L, 2, &req_len);
    int timeout_ms = (int)get_integer(L, 3, 1500);

    if (!sock_path || path_len == 0 || path_len >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        p_lua_pushnil(L);
        p_lua_pushstring(L, "invalid socket path");
        return 2;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (fd < 0) {
        p_lua_pushnil(L);
        p_lua_pushstring(L, strerror(errno));
        return 2;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    memcpy(addr.sun_path, sock_path, path_len);

    int rc = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
    if (rc < 0 && errno != EINPROGRESS) {
        int err = errno;
        close(fd);
        p_lua_pushnil(L);
        p_lua_pushstring(L, strerror(err));
        return 2;
    }

    if (rc < 0) {
        struct pollfd pfd = { .fd = fd, .events = POLLOUT, .revents = 0 };
        if (poll(&pfd, 1, timeout_ms) <= 0) {
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, "connect timeout");
            return 2;
        }
        int so_err = 0;
        socklen_t slen = sizeof(so_err);
        if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_err, &slen) < 0 || so_err != 0) {
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, so_err ? strerror(so_err) : "socket connect error");
            return 2;
        }
    }

    size_t sent = 0;
    while (req_data && sent < req_len) {
        struct pollfd pfd = { .fd = fd, .events = POLLOUT, .revents = 0 };
        int pr = poll(&pfd, 1, timeout_ms);
        if (pr <= 0) {
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, "write timeout");
            return 2;
        }
        ssize_t w = send(fd, req_data + sent, req_len - sent, MSG_NOSIGNAL);
        if (w < 0) {
            if (errno == EINTR || errno == EAGAIN) continue;
            int err = errno;
            close(fd);
            p_lua_pushnil(L);
            p_lua_pushstring(L, strerror(err));
            return 2;
        }
        sent += (size_t)w;
    }

    char stack_buf[16384];
    char *buf = stack_buf;
    size_t cap = sizeof(stack_buf);
    size_t total = 0;
    int have_reply = 0;

    for (;;) {
        struct pollfd pfd = { .fd = fd, .events = POLLIN, .revents = 0 };
        int wait_ms = have_reply ? 15 : timeout_ms;
        int pr = poll(&pfd, 1, wait_ms);
        if (pr < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (pr == 0) break;

        if (total == cap) {
            size_t new_cap = cap * 2;
            char *new_buf;
            if (buf == stack_buf) {
                new_buf = (char *)malloc(new_cap);
                if (new_buf) memcpy(new_buf, stack_buf, total);
            } else {
                new_buf = (char *)realloc(buf, new_cap);
            }
            if (!new_buf) {
                if (buf != stack_buf) free(buf);
                close(fd);
                p_lua_pushnil(L);
                p_lua_pushstring(L, "out of memory");
                return 2;
            }
            buf = new_buf;
            cap = new_cap;
        }

        ssize_t r = recv(fd, buf + total, cap - total, 0);
        if (r < 0) {
            if (errno == EINTR) continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                if (have_reply) break;
                continue;
            }
            break;
        }
        if (r == 0) break;
        total += (size_t)r;
        have_reply = 1;

        if (memchr(buf, '\n', total) != NULL && req_len > 0 && req_data[req_len - 1] == '\n') {
            break;
        }
    }

    close(fd);
    p_lua_pushlstring(L, buf, total);
    if (buf != stack_buf) free(buf);
    return 1;
}

static ssize_t read_small_file(const char *path, char *buf, size_t buf_sz) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t total = 0;
    while ((size_t)total < buf_sz - 1) {
        ssize_t r = read(fd, buf + total, buf_sz - 1 - (size_t)total);
        if (r < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (r == 0) break;
        total += r;
    }
    close(fd);
    buf[total] = '\0';
    return total;
}

static uint64_t prev_cpu_total = 0;
static uint64_t prev_cpu_idle  = 0;
static double   last_cpu_pct   = 0.0;

static uint64_t prev_net_rx    = 0;
static uint64_t prev_net_tx    = 0;
static int64_t  prev_net_ns    = 0;
static double   last_rx_bps    = 0.0;
static double   last_tx_bps    = 0.0;

static const char *cached_temp_path = NULL;
static const char *temp_candidate_paths[] = {
    "/sys/class/thermal/thermal_zone0/temp",
    "/sys/class/thermal/thermal_zone1/temp",
    "/sys/class/thermal/thermal_zone2/temp",
    "/sys/class/hwmon/hwmon0/temp1_input",
    "/sys/class/hwmon/hwmon1/temp1_input",
    "/sys/class/hwmon/hwmon2/temp1_input",
    "/sys/class/hwmon/hwmon3/temp1_input",
    NULL
};

static int l_read_sys_telemetry(lua_State *L) {
    char buf[4096];

    double cpu_pct = last_cpu_pct;
    if (read_small_file("/proc/stat", buf, sizeof(buf)) > 0) {
        unsigned long long user = 0, nice = 0, sys = 0, idle = 0;
        unsigned long long iowait = 0, irq = 0, softirq = 0, steal = 0;
        if (sscanf(buf, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
                   &user, &nice, &sys, &idle, &iowait, &irq, &softirq, &steal) >= 4) {
            uint64_t idle_all = idle + iowait;
            uint64_t total = user + nice + sys + idle_all + irq + softirq + steal;
            uint64_t d_total = total - prev_cpu_total;
            uint64_t d_idle  = idle_all - prev_cpu_idle;
            if (prev_cpu_total > 0 && d_total > 0) {
                cpu_pct = (double)(d_total - d_idle) * 100.0 / (double)d_total;
                if (cpu_pct < 0.0) cpu_pct = 0.0;
                if (cpu_pct > 100.0) cpu_pct = 100.0;
                last_cpu_pct = cpu_pct;
            }
            prev_cpu_total = total;
            prev_cpu_idle  = idle_all;
        }
    }

    uint64_t mem_total = 0, mem_free = 0, mem_avail = 0, buffers = 0, cached = 0;
    uint64_t swap_total = 0, swap_free = 0;
    if (read_small_file("/proc/meminfo", buf, sizeof(buf)) > 0) {
        char *line = buf;
        while (line && *line) {
            char *next = strchr(line, '\n');
            if (next) *next++ = '\0';
            unsigned long long val = 0;
            if (sscanf(line, "MemTotal: %llu", &val) == 1) mem_total = val;
            else if (sscanf(line, "MemFree: %llu", &val) == 1) mem_free = val;
            else if (sscanf(line, "MemAvailable: %llu", &val) == 1) mem_avail = val;
            else if (sscanf(line, "Buffers: %llu", &val) == 1) buffers = val;
            else if (sscanf(line, "Cached: %llu", &val) == 1) cached = val;
            else if (sscanf(line, "SwapTotal: %llu", &val) == 1) swap_total = val;
            else if (sscanf(line, "SwapFree: %llu", &val) == 1) swap_free = val;
            line = next;
        }
    }
    if (mem_avail == 0) mem_avail = mem_free + buffers + cached;
    uint64_t mem_used = (mem_total > mem_avail) ? (mem_total - mem_avail) : 0;
    double mem_pct = (mem_total > 0) ? ((double)mem_used * 100.0 / (double)mem_total) : 0.0;
    uint64_t swap_used = (swap_total > swap_free) ? (swap_total - swap_free) : 0;
    double swap_pct = (swap_total > 0) ? ((double)swap_used * 100.0 / (double)swap_total) : 0.0;

    double temp_c = 0.0;
    char tbuf[64];
    if (cached_temp_path && read_small_file(cached_temp_path, tbuf, sizeof(tbuf)) > 0) {
        long raw = strtol(tbuf, NULL, 10);
        if (raw > 1000) temp_c = (double)raw / 1000.0;
        else if (raw > 0) temp_c = (double)raw;
    } else {
        for (int i = 0; temp_candidate_paths[i] != NULL; i++) {
            if (read_small_file(temp_candidate_paths[i], tbuf, sizeof(tbuf)) > 0) {
                long raw = strtol(tbuf, NULL, 10);
                if (raw > 0) {
                    cached_temp_path = temp_candidate_paths[i];
                    temp_c = (raw > 1000) ? ((double)raw / 1000.0) : (double)raw;
                    break;
                }
            }
        }
    }

    double load_1 = 0.0, load_5 = 0.0, load_15 = 0.0;
    if (read_small_file("/proc/loadavg", tbuf, sizeof(tbuf)) > 0) {
        sscanf(tbuf, "%lf %lf %lf", &load_1, &load_5, &load_15);
    }

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    int64_t now_ns = (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;

    if (read_small_file("/proc/net/dev", buf, sizeof(buf)) > 0) {
        uint64_t total_rx = 0, total_tx = 0;
        char *line = buf;
        int line_no = 0;
        while (line && *line) {
            char *next = strchr(line, '\n');
            if (next) *next++ = '\0';
            line_no++;
            if (line_no > 2) {
                char *colon = strchr(line, ':');
                if (colon) {
                    *colon = '\0';
                    char *ifname = line;
                    while (*ifname == ' ' || *ifname == '\t') ifname++;
                    if (strcmp(ifname, "lo") != 0) {
                        unsigned long long rx_b = 0, tx_b = 0, dummy = 0;
                        if (sscanf(colon + 1, "%llu %llu %llu %llu %llu %llu %llu %llu %llu",
                                   &rx_b, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &tx_b) == 9) {
                            total_rx += rx_b;
                            total_tx += tx_b;
                        }
                    }
                }
            }
            line = next;
        }

        if (prev_net_ns > 0 && now_ns > prev_net_ns) {
            double dt = (double)(now_ns - prev_net_ns) / 1e9;
            if (dt > 0.05) {
                last_rx_bps = (total_rx >= prev_net_rx) ? ((double)(total_rx - prev_net_rx) / dt) : 0.0;
                last_tx_bps = (total_tx >= prev_net_tx) ? ((double)(total_tx - prev_net_tx) / dt) : 0.0;
                prev_net_rx = total_rx;
                prev_net_tx = total_tx;
                prev_net_ns = now_ns;
            }
        } else {
            prev_net_rx = total_rx;
            prev_net_tx = total_tx;
            prev_net_ns = now_ns;
        }
    }

    p_lua_createtable(L, 0, 14);
    if (p_lua_pushnumber) {
        p_lua_pushnumber(L, cpu_pct);
        p_lua_setfield(L, -2, "cpu_percent");
        p_lua_pushnumber(L, mem_pct);
        p_lua_setfield(L, -2, "mem_percent");
        p_lua_pushnumber(L, swap_pct);
        p_lua_setfield(L, -2, "swap_percent");
        p_lua_pushnumber(L, temp_c);
        p_lua_setfield(L, -2, "temp_c");
        p_lua_pushnumber(L, load_1);
        p_lua_setfield(L, -2, "load_1m");
        p_lua_pushnumber(L, load_5);
        p_lua_setfield(L, -2, "load_5m");
        p_lua_pushnumber(L, load_15);
        p_lua_setfield(L, -2, "load_15m");
        p_lua_pushnumber(L, last_rx_bps);
        p_lua_setfield(L, -2, "net_rx_bps");
        p_lua_pushnumber(L, last_tx_bps);
        p_lua_setfield(L, -2, "net_tx_bps");
    }
    if (p_lua_pushinteger) {
        p_lua_pushinteger(L, (lua_Integer)mem_total);
        p_lua_setfield(L, -2, "mem_total_kb");
        p_lua_pushinteger(L, (lua_Integer)mem_avail);
        p_lua_setfield(L, -2, "mem_avail_kb");
        p_lua_pushinteger(L, (lua_Integer)mem_used);
        p_lua_setfield(L, -2, "mem_used_kb");
        p_lua_pushinteger(L, (lua_Integer)swap_total);
        p_lua_setfield(L, -2, "swap_total_kb");
        p_lua_pushinteger(L, (lua_Integer)swap_used);
        p_lua_setfield(L, -2, "swap_used_kb");
    }
    return 1;
}

static int l_monotonic_us(lua_State *L) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    lua_Integer us = (lua_Integer)ts.tv_sec * 1000000 + (lua_Integer)(ts.tv_nsec / 1000);
    if (p_lua_pushinteger) {
        p_lua_pushinteger(L, us);
    } else if (p_lua_pushnumber) {
        p_lua_pushnumber(L, (lua_Number)us);
    } else {
        p_lua_pushnil(L);
    }
    return 1;
}

/* ---------------------------------------------------------------------------
 * Framework-facing spellings and small POSIX helpers
 *
 * `ignis/utils/file.lua` and `ignis/services/fetch.lua` address fast file I/O
 * as `read_file_fast` / `write_file_fast` / `file_exists` / `is_dir` /
 * `count_dir_entries`, and `test.lua` also expects `monotonic_time_us` and
 * `version`. The `*_fast` / `*_us` names are thin wrappers over the
 * implementations above so both spellings cannot drift apart.
 * ------------------------------------------------------------------------ */

static int l_version(lua_State *L) {
    p_lua_pushstring(L, "0.7.0-native-c11");
    return 1;
}

static int l_read_file_fast(lua_State *L) {
    return l_read_file(L);
}

static int l_write_file_fast(lua_State *L) {
    return l_write_file(L);
}

static int l_monotonic_time_us(lua_State *L) {
    return l_monotonic_us(L);
}

static int l_file_exists(lua_State *L) {
    const char *path = p_lua_tolstring(L, 1, NULL);
    struct stat st;
    p_lua_pushboolean(L, (path && stat(path, &st) == 0) ? 1 : 0);
    return 1;
}

static int l_is_dir(lua_State *L) {
    const char *path = p_lua_tolstring(L, 1, NULL);
    struct stat st;
    p_lua_pushboolean(L, (path && stat(path, &st) == 0 && S_ISDIR(st.st_mode)) ? 1 : 0);
    return 1;
}

static int l_count_dir_entries(lua_State *L) {
    const char *path = p_lua_tolstring(L, 1, NULL);
    DIR *dir = path ? opendir(path) : NULL;
    if (!dir) {
        p_lua_pushinteger(L, 0);
        return 1;
    }

    lua_Integer count = 0;
    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        if (strcmp(ent->d_name, "ALPM_DB_VERSION") == 0) continue;
        count++;
    }
    closedir(dir);

    p_lua_pushinteger(L, count);
    return 1;
}

static void register_fn(lua_State *L, const char *name, lua_CFunction fn) {
    p_lua_pushcclosure(L, fn, 0);
    p_lua_setfield(L, -2, name);
}

int luaopen_ignis_native(lua_State *L) {
    if (!resolve_lua_api()) {
        return 0;
    }

    p_lua_createtable(L, 0, 13);
    register_fn(L, "get_self",           l_get_self);
    register_fn(L, "read_file",          l_read_file);
    register_fn(L, "write_file",         l_write_file);
    register_fn(L, "read_file_fast",     l_read_file_fast);
    register_fn(L, "write_file_fast",    l_write_file_fast);
    register_fn(L, "file_exists",        l_file_exists);
    register_fn(L, "is_dir",             l_is_dir);
    register_fn(L, "count_dir_entries",  l_count_dir_entries);
    register_fn(L, "unix_request",       l_unix_request);
    register_fn(L, "read_sys_telemetry", l_read_sys_telemetry);
    register_fn(L, "monotonic_us",       l_monotonic_us);
    register_fn(L, "monotonic_time_us",  l_monotonic_time_us);
    register_fn(L, "version",            l_version);
    return 1;
}
