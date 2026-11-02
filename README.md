# 💾 server-backup-script

**Backup diário configurável para servidores Linux: bancos de dados, pastas importantes, rotação automática e cópia opcional para a nuvem.**

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![rclone](https://img.shields.io/badge/rclone-3F79AD?logo=rclone&logoColor=white)

Um único script, sem dependências além das ferramentas dos bancos que você usa. Pensado para rodar no `cron` de uma VPS.

## ✨ Funcionalidades

- **Bancos**: MariaDB/MySQL (`mysqldump`), PostgreSQL (`pg_dump`) e SQLite (cópia consistente com `.backup`)
- **Diretórios** compactados em `.tgz`, com lista de exclusões (ex.: `venv`, `node_modules`)
- **Verificação de integridade** dos arquivos gerados
- **Rotação**: mantém só os últimos *N* dias localmente
- **Cópia remota opcional** com `rclone` (Google Drive, S3, etc.), conferida após o envio e com retenção própria
- **Aviso de falha** por um comando que você define (e-mail, webhook, mensagem...)
- **Credenciais fora da linha de comando**: o MariaDB usa um arquivo `.cnf` com permissão 600

## 🧰 Tecnologias

![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?logo=mariadb&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white)
![rclone](https://img.shields.io/badge/rclone-3F79AD?logo=rclone&logoColor=white)

Bash · tar · gzip · mysqldump · pg_dump · sqlite3 · rclone (opcional)

## 📋 Requisitos

- Linux com `bash`, `tar`, `gzip` e `find`
- Os clientes dos bancos que você quiser salvar (`mysqldump`, `pg_dump`, `sqlite3`)
- Opcional: `rclone` configurado

Este projeto é um script de servidor, sem imagem Docker.

## 🚀 Instalação

```bash
git clone https://github.com/alexandrosakai/server-backup-script.git
cd server-backup-script

sudo install -m 700 backup.sh /usr/local/bin/server-backup
sudo mkdir -p /etc/server-backup
sudo install -m 600 backup.conf.example /etc/server-backup/backup.conf
sudo install -m 600 mysql.cnf.example   /etc/server-backup/mysql.cnf
```

## ⚙️ Configuração

Edite `/etc/server-backup/backup.conf`:

| Variável | Descrição |
|---|---|
| `BACKUP_DIR` | onde guardar os backups (padrão `/var/backups/server-backup`) |
| `RETENTION_DAYS` | quantos dias manter localmente |
| `MYSQL_DATABASES`, `MYSQL_DEFAULTS_FILE` | bancos MariaDB/MySQL e arquivo de credenciais |
| `POSTGRES_DATABASES` | bancos PostgreSQL (use `PGHOST`/`PGUSER`/`PGPASSWORD` ou `~/.pgpass`) |
| `SQLITE_FILES` | arquivos SQLite |
| `DIRECTORIES`, `EXCLUDES` | pastas a salvar e padrões a ignorar |
| `RCLONE_REMOTE`, `RCLONE_RETENTION_DAYS` | destino remoto e retenção na nuvem (opcional) |
| `NOTIFY_COMMAND` | comando executado em caso de falha (recebe `BACKUP_MESSAGE`) |

Edite `/etc/server-backup/mysql.cnf` com um usuário de leitura:

```ini
[client]
user=backup
password=SUA_SENHA
```

## 🧭 Como usar

Teste uma vez e agende no `cron`:

```bash
sudo server-backup
sudo tail /var/backups/server-backup/backup.log

# todo dia às 03:15
echo '15 3 * * * root /usr/local/bin/server-backup' | sudo tee /etc/cron.d/server-backup
```

Cada execução cria `BACKUP_DIR/AAAA-MM-DD/` com `mysql-*.sql.gz`, `postgres-*.sql.gz`, `sqlite-*.gz` e `dir-*.tgz`.

**Restaurar:**

```bash
gunzip -c mysql-app_db.sql.gz | mysql app_db
tar xzf dir-opt_app.tgz -C /
```

> Teste a restauração periodicamente. Backup que nunca foi restaurado não é backup.

## 📁 Estrutura de pastas

```
server-backup-script/
├── backup.sh              # o script
├── backup.conf.example    # modelo de configuração
└── mysql.cnf.example      # modelo de credenciais do MariaDB/MySQL
```

## 🗺️ Roadmap

- [ ] Criptografia dos arquivos antes do envio
- [ ] Suporte a MongoDB e Redis
- [ ] Unidade `systemd` + timer como alternativa ao cron
- [ ] Modo de simulação (`--dry-run`)
- [ ] Testes automatizados com `bats`

## 🤝 Como contribuir

1. Faça um fork e crie uma branch: `git checkout -b minha-melhoria`
2. Rode `shellcheck backup.sh` antes de abrir o Pull Request
3. Descreva o cenário testado

## 📄 Licença

Distribuído sob a licença MIT. Veja o arquivo [LICENSE](LICENSE).
