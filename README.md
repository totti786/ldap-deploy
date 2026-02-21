# LDAP Linux Deployment

A comprehensive, production-ready OpenLDAP deployment for Linux environments. Includes Docker containers, Ansible automation, user management tools, and monitoring.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LDAP Infrastructure                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │   OpenLDAP      │────▶│   Replicas      │────▶│   Backups       │       │
│  │   Primary       │     │   (Multi-Master)│     │   (Automated)   │       │
│  │   (Provider)    │     │                 │     │                 │       │
│  └────────┬────────┘     └─────────────────┘     └─────────────────┘       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐       │
│  │  phpLDAPadmin   │     │   Kerberos      │     │    Samba        │       │
│  │  (Web UI)       │     │   (Auth)        │     │   (File Share)  │       │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                     Client Integration                           │       │
│  │  SSH │ Sudo │ Apache │ Nginx │ PostgreSQL │ MySQL │ Applications │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **OpenLDAP Server**: Multi-master replication support
- **phpLDAPadmin**: Web-based management interface
- **Kerberos Integration**: Single sign-on authentication
- **Samba Integration**: Active Directory compatibility
- **Ansible Automation**: Complete infrastructure as code
- **User Management**: Scripts for bulk operations
- **Backup & Recovery**: Automated backup with point-in-time recovery
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **Security Hardening**: TLS, password policies, access controls
- **Migration Tools**: Import from other LDAP/AD systems

## Quick Start

### Prerequisites

- Docker and Docker Compose
- 4GB RAM minimum (8GB recommended)
- Domain name for LDAP services
- SSL certificates (or use Let's Encrypt)

### 1. Clone and Configure

```bash
git clone https://github.com/totti786/ldap-deploy.git
cd ldap-deploy

# Copy environment template
cp .env.example .env
vim .env
```

### 2. Deploy with Docker

```bash
# Start all services
docker-compose up -d

# Initialize LDAP structure
./scripts/init-ldap.sh

# Verify deployment
./scripts/health-check.sh
```

### 3. Deploy with Ansible (Alternative)

```bash
cd ansible

# Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
vim inventory/hosts.yml

# Run deployment
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Project Structure

```
ldap-deploy/
├── docker/
│   ├── openldap/           # OpenLDAP container configs
│   ├── phpldapadmin/       # Web UI container
│   ├── samba/              # Samba AD integration
│   └── kerberos/           # Kerberos KDC
├── ansible/
│   ├── roles/              # Ansible roles
│   ├── playbooks/          # Deployment playbooks
│   ├── inventory/          # Host configurations
│   └── group_vars/         # Variable files
├── scripts/
│   ├── users/              # User management scripts
│   ├── backup/             # Backup and recovery
│   └── migration/          # Migration utilities
├── monitoring/             # Prometheus configs
├── docs/                   # Documentation
└── docker-compose.yml
```

## Configuration

### Environment Variables

```bash
# .env.example
LDAP_DOMAIN=example.com
LDAP_ORGANIZATION="Example Corp"
LDAP_ADMIN_PASSWORD=your_secure_password
LDAP_CONFIG_PASSWORD=your_config_password
LDAP_BACKEND=mdb
LDAP_TLS=true
LDAP_TLS_CRT_FILENAME=ldap.crt
LDAP_TLS_KEY_FILENAME=ldap.key
LDAP_TLS_CA_CRT_FILENAME=ca.crt

# Kerberos
KRB_REALM=EXAMPLE.COM
KRB_ADMIN_PASSWORD=your_krb_password

# Samba
SAMBA_DOMAIN=EXAMPLE
SAMBA_REALM=example.com
SAMBA_ADMIN_PASSWORD=your_samba_password
```

### LDAP Structure

```
dc=example,dc=com
├── ou=People              # User accounts
│   └── uid=username
├── ou=Groups              # POSIX groups
│   └── cn=groupname
├── ou=Services            # Service accounts
│   └── uid=service-name
├── ou=Sudoers             # Sudo rules
│   └── cn=username
├── ou=Hosts               # Host entries
│   └── cn=hostname
└── ou=Applications        # App configurations
    └── ou=AppName
```

## User Management

### Create User

```bash
# Interactive user creation
./scripts/users/create-user.sh

# Bulk import from CSV
./scripts/users/bulk-import.sh users.csv

# With specific attributes
./scripts/users/create-user.sh \
  --uid jsmith \
  --cn "John Smith" \
  --email jsmith@example.com \
  --shell /bin/bash \
  --groups developers,admin
```

### Modify User

```bash
# Reset password
./scripts/users/reset-password.sh jsmith

# Add to group
./scripts/users/add-to-group.sh jsmith developers

# Disable account
./scripts/users/disable-user.sh jsmith

# Enable account
./scripts/users/enable-user.sh jsmith
```

### Bulk Operations

```bash
# Export all users
./scripts/users/export-users.sh > users.ldif

# Import from LDIF
./scripts/users/import-users.sh users.ldif

# Sync from CSV
./scripts/users/sync-from-csv.sh employees.csv
```

## Client Configuration

### Ubuntu/Debian

```bash
# Install required packages
apt-get install -y libnss-ldapd libpam-ldapd nscd

# Configure NSS
./scripts/client/configure-client.sh --os debian --server ldap.example.com

# Or use Ansible
ansible-playbook -i inventory playbooks/configure-client.yml
```

### RHEL/CentOS

```bash
# Install required packages
yum install -y nss-pam-ldapd sssd

# Configure
./scripts/client/configure-client.sh --os rhel --server ldap.example.com
```

### SSH Integration

```bash
# Configure SSH to use LDAP
./scripts/client/ssh-integration.sh

# Enables:
# - SSH key storage in LDAP
# - LDAP-based host access control
# - Session recording
```

## Backup & Recovery

### Automated Backups

```bash
# Configure daily backups
./scripts/backup/setup-cron.sh

# Manual backup
./scripts/backup/backup.sh

# Backup locations:
# - /var/backups/ldap/slapd-data/
# - /var/backups/ldap/config/
# - /var/backups/ldap/ldif/
```

### Recovery

```bash
# Full restore
./scripts/backup/restore.sh /var/backups/ldap/backup-2024-01-15/

# Point-in-time recovery
./scripts/backup/pitr.sh --timestamp "2024-01-15 14:30:00"

# Single entry restore
./scripts/backup/restore-entry.sh uid=jsmith,ou=People,dc=example,dc=com
```

## Monitoring

### Prometheus Metrics

Access metrics at `http://ldap-server:9101/metrics`

Key metrics:
- `ldap_connections_active`
- `ldap_operations_total`
- `ldap_search_duration_seconds`
- `ldap_bind_success_total`
- `ldap_replication_lag_seconds`

### Grafana Dashboard

Import dashboard: `monitoring/grafana-dashboard.json`

## Security

### TLS Configuration

```bash
# Generate certificates
./scripts/security/generate-certs.sh

# Use custom certificates
cp your-cert.pem docker/openldap/certs/ldap.crt
cp your-key.pem docker/openldap/certs/ldap.key
cp ca-cert.pem docker/openldap/certs/ca.crt

# Enforce TLS
./scripts/security/enforce-tls.sh
```

### Password Policies

```bash
# Apply password policy
./scripts/security/password-policy.sh

# Policies include:
# - Minimum length: 12 characters
# - Complexity requirements
# - Password history: 24 passwords
# - Max age: 90 days
# - Lockout after 5 failures
```

### Access Controls

```bash
# Apply ACLs
./scripts/security/configure-acl.sh

# Default ACLs:
# - Users can read own entry
# - Admins have full access
# - Services have limited read
# - Anonymous bind disabled
```

## Replication

### Multi-Master Setup

```bash
# Initialize multi-master replication
./scripts/replication/setup-multimaster.sh \
  --master1 ldap1.example.com \
  --master2 ldap2.example.com

# Check replication status
./scripts/replication/check-status.sh

# Manual sync
./scripts/replication/sync-now.sh
```

### Consumer Setup

```bash
# Add read-only replica
./scripts/replication/add-consumer.sh ldap-replica.example.com
```

## Migration

### From Active Directory

```bash
# Export from AD
./scripts/migration/ad-export.sh \
  --ad-server ad.example.com \
  --admin-user "cn=admin,cn=users,dc=example,dc=com"

# Import to LDAP
./scripts/migration/ad-import.sh ad-export.ldif
```

### From Other LDAP

```bash
# Generic LDAP export
./scripts/migration/ldap-export.sh \
  --server old-ldap.example.com \
  --base-dn "dc=example,dc=com"

# Transform and import
./scripts/migration/ldap-import.sh export.ldif
```

## Troubleshooting

### Common Issues

1. **Cannot bind to LDAP**
   ```bash
   # Check service status
   docker logs openldap
   
   # Verify TLS
   openssl s_client -connect localhost:636
   
   # Test bind
   ldapsearch -x -H ldaps://localhost -D "cn=admin,dc=example,dc=com" -W
   ```

2. **Replication not working**
   ```bash
   # Check replication status
   ./scripts/replication/check-status.sh
   
   # Force resync
   ./scripts/replication/resync.sh
   ```

3. **Client authentication fails**
   ```bash
   # Test LDAP connectivity
   getent passwd username
   
   # Check PAM config
   pam-auth-update
   ```

## Performance Tuning

```bash
# Database optimization
./scripts/tuning/optimize-db.sh

# Cache configuration
./scripts/tuning/configure-cache.sh

# Connection pooling
./scripts/tuning/connection-pool.sh
```

## License

MIT License - see [LICENSE](LICENSE)

## Author

**Tarek Deshli**
- GitHub: [@totti786](https://github.com/totti786)
- LinkedIn: [tarekdeshli](https://linkedin.com/in/tarekdeshli)
