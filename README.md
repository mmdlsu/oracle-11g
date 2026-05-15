# Oracle Database 11g 11.2.0.4 Docker Image

在 Docker 中运行 Oracle Database 11g Enterprise Edition 11.2.0.4。镜像内置 Oracle 安装包，**首次启动时自动完成数据库安装与初始化**，无需手动干预。

---

## 快速开始

```yaml
services:
  database:
    image: mmdlsu/oracle11g
    privileged: true
    ports:
      - "1521:1521"
      - "8080:8080"
    volumes:
      - ./oracle-data:/opt/oracle
    environment:
      TZ: Asia/Shanghai
      ORACLE_SID: ORCL
      ORACLE_PWD: 123456
      ORACLE_CHARACTERSET: AL32UTF8
      PASSWORD_NO_EXPIRE: true
      LOGIN_ATTEMPTS_UNLIMITED: true
```

```bash
docker compose up -d
```

> ⏱ **首次启动需要数分钟**，容器将在后台自动完成 Oracle 安装与建库，请耐心等待。

---

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `ORACLE_SID` | `orcl` | 数据库 SID |
| `ORACLE_PWD` | `oracle` | SYS / SYSTEM 用户密码 |
| `ORACLE_CHARACTERSET` | `AL32UTF8` | 数据库字符集 |
| `PASSWORD_NO_EXPIRE` | `true` | 设置默认 profile 的密码过期时间为永不过期；设为 `false` 时不修改 |
| `LOGIN_ATTEMPTS_UNLIMITED` | `true` | 设置默认 profile 的密码登录尝试次数为不受限；设为 `false` 时不修改 |

---

## 端口

| 端口 | 用途 |
|---|---|
| `1521` | Oracle 监听器（SQL 连接） |
| `8080` | Oracle HTTP / APEX |

---

## 数据持久化

数据库文件存储于容器内的 `/opt/oracle` 目录，建议挂载到宿主机：

```yaml
volumes:
  - ./oracle-data:/opt/oracle
```

| 场景 | 行为 |
|---|---|
| `./oracle-data` 为空 | 自动执行首次安装与建库 |
| `./oracle-data` 已有数据 | 直接启动已有数据库，跳过安装 |

> 如需重建数据库，停止容器后删除 `oracle-data` 目录，再重新启动即可。

---

## 连接数据库

```bash
sqlplus system/123456@//127.0.0.1:1521/ORCL
```

请将 `123456` 和 `ORCL` 替换为你在环境变量中配置的实际值。

---

## 注意事项

- **必须设置 `privileged: true`**，容器需要此权限来正确配置共享内存（`/dev/shm`）。
- 首次启动耗时较长，属于正常现象，可通过 `docker compose logs -f` 观察安装进度。
- 重置数据库：停止容器 → 删除 `oracle-data` 目录 → 重新启动。
