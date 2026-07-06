import Foundation

enum CreateContainerGroupMode: String, CaseIterable, Identifiable, Sendable {
    case none
    case existing
    case new

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "No group"
        case .existing: "Existing group"
        case .new: "Create new group"
        }
    }
}

struct PortMapping: Identifiable, Hashable, Sendable {
    let id: UUID
    var hostPort: String
    var containerPort: String
    var protocolName: String

    init(id: UUID = UUID(), hostPort: String = "", containerPort: String = "", protocolName: String = "tcp") {
        self.id = id
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.protocolName = protocolName
    }

    var cliValue: String? {
        guard let host = Int(hostPort.trimmingCharacters(in: .whitespaces)),
              let container = Int(containerPort.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        let proto = protocolName.lowercased()
        if proto == "tcp" {
            return "\(host):\(container)"
        }
        return "\(host):\(container)/\(proto)"
    }
}

struct VolumeMount: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case bind
        case named

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bind: "Bind mount"
            case .named: "Named volume"
            }
        }
    }

    let id: UUID
    var kind: Kind
    var hostPath: String
    var volumeName: String
    var containerPath: String
    var readOnly: Bool

    init(
        id: UUID = UUID(),
        kind: Kind = .bind,
        hostPath: String = "",
        volumeName: String = "",
        containerPath: String = "",
        readOnly: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.hostPath = hostPath
        self.volumeName = volumeName
        self.containerPath = containerPath
        self.readOnly = readOnly
    }

    var cliValue: String? {
        let target = containerPath.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }

        switch kind {
        case .bind:
            let host = hostPath.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else { return nil }
            if readOnly {
                return "\(host):\(target):ro"
            }
            return "\(host):\(target)"
        case .named:
            let volume = volumeName.trimmingCharacters(in: .whitespaces)
            guard !volume.isEmpty else { return nil }
            if readOnly {
                return "\(volume):\(target):ro"
            }
            return "\(volume):\(target)"
        }
    }

    var displayValue: String {
        switch kind {
        case .bind:
            let host = hostPath.isEmpty ? "?" : hostPath
            return "\(host) → \(containerPath)\(readOnly ? " (ro)" : "")"
        case .named:
            let volume = volumeName.isEmpty ? "?" : volumeName
            return "\(volume) → \(containerPath)\(readOnly ? " (ro)" : "")"
        }
    }
}

struct EnvVariable: Identifiable, Hashable, Sendable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }

    var cliValue: String? {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return nil }
        return "\(trimmedKey)=\(value)"
    }
}

struct ImagePreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let image: String
    let category: String
    let description: String
    let defaultPorts: [PortMapping]
    let defaultVolumes: [VolumeMount]
    let defaultEnv: [EnvVariable]
    let defaultCommand: String
    let defaultMemory: String
    let defaultCPUs: String

    init(
        id: String,
        name: String,
        image: String,
        category: String,
        description: String,
        defaultPorts: [PortMapping] = [],
        defaultVolumes: [VolumeMount] = [],
        defaultEnv: [EnvVariable] = [],
        defaultCommand: String = "",
        defaultMemory: String = "",
        defaultCPUs: String = ""
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.category = category
        self.description = description
        self.defaultPorts = defaultPorts
        self.defaultVolumes = defaultVolumes
        self.defaultEnv = defaultEnv
        self.defaultCommand = defaultCommand
        self.defaultMemory = defaultMemory
        self.defaultCPUs = defaultCPUs
    }
}

enum ImagePresets {
    static let all: [ImagePreset] = [
        ImagePreset(id: "alpine", name: "Alpine", image: "alpine:latest", category: "Base", description: "Minimal Linux"),
        ImagePreset(id: "ubuntu", name: "Ubuntu", image: "ubuntu:24.04", category: "Base", description: "Popular Debian-based distro"),
        ImagePreset(id: "debian", name: "Debian", image: "debian:bookworm-slim", category: "Base", description: "Stable Debian"),
        ImagePreset(id: "fedora", name: "Fedora", image: "fedora:41", category: "Base", description: "Red Hat community distro"),
        ImagePreset(id: "amazonlinux", name: "Amazon Linux", image: "amazonlinux:2023", category: "Base", description: "AWS optimized Linux"),
        ImagePreset(id: "nginx", name: "Nginx", image: "nginx:alpine", category: "Web", description: "Web server / reverse proxy", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80")]),
        ImagePreset(id: "httpd", name: "Apache HTTPD", image: "httpd:alpine", category: "Web", description: "Apache web server", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80")]),
        ImagePreset(id: "caddy", name: "Caddy", image: "caddy:alpine", category: "Web", description: "Automatic HTTPS web server", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80"), PortMapping(hostPort: "8443", containerPort: "443")]),
        ImagePreset(id: "traefik", name: "Traefik", image: "traefik:latest", category: "Web", description: "Edge router / load balancer", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80"), PortMapping(hostPort: "8443", containerPort: "443"), PortMapping(hostPort: "9090", containerPort: "8080")]),
        ImagePreset(id: "postgres", name: "PostgreSQL", image: "postgres:16-alpine", category: "Database", description: "Relational database", defaultPorts: [PortMapping(hostPort: "5432", containerPort: "5432")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/postgres", containerPath: "/var/lib/postgresql/data")], defaultEnv: [EnvVariable(key: "POSTGRES_PASSWORD", value: "postgres"), EnvVariable(key: "POSTGRES_USER", value: "postgres"), EnvVariable(key: "POSTGRES_DB", value: "app")]),
        ImagePreset(id: "mysql", name: "MySQL", image: "mysql:8", category: "Database", description: "Popular SQL database", defaultPorts: [PortMapping(hostPort: "3306", containerPort: "3306")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/mysql", containerPath: "/var/lib/mysql")], defaultEnv: [EnvVariable(key: "MYSQL_ROOT_PASSWORD", value: "root"), EnvVariable(key: "MYSQL_DATABASE", value: "app")]),
        ImagePreset(id: "mariadb", name: "MariaDB", image: "mariadb:11", category: "Database", description: "MySQL-compatible database", defaultPorts: [PortMapping(hostPort: "3306", containerPort: "3306")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/mariadb", containerPath: "/var/lib/mysql")], defaultEnv: [EnvVariable(key: "MARIADB_ROOT_PASSWORD", value: "root"), EnvVariable(key: "MARIADB_DATABASE", value: "app")]),
        ImagePreset(id: "redis", name: "Redis", image: "redis:7-alpine", category: "Database", description: "In-memory cache / store", defaultPorts: [PortMapping(hostPort: "6379", containerPort: "6379")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/redis", containerPath: "/data")]),
        ImagePreset(id: "mongo", name: "MongoDB", image: "mongo:7", category: "Database", description: "Document database", defaultPorts: [PortMapping(hostPort: "27017", containerPort: "27017")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/mongo", containerPath: "/data/db")], defaultEnv: [EnvVariable(key: "MONGO_INITDB_ROOT_USERNAME", value: "root"), EnvVariable(key: "MONGO_INITDB_ROOT_PASSWORD", value: "root")]),
        ImagePreset(id: "memcached", name: "Memcached", image: "memcached:alpine", category: "Database", description: "Distributed memory cache", defaultPorts: [PortMapping(hostPort: "11211", containerPort: "11211")]),
        ImagePreset(id: "elasticsearch", name: "Elasticsearch", image: "docker.elastic.co/elasticsearch/elasticsearch:8.15.0", category: "Database", description: "Search and analytics engine", defaultPorts: [PortMapping(hostPort: "9200", containerPort: "9200")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/elasticsearch", containerPath: "/usr/share/elasticsearch/data")], defaultEnv: [EnvVariable(key: "discovery.type", value: "single-node"), EnvVariable(key: "xpack.security.enabled", value: "false")], defaultMemory: "2G"),
        ImagePreset(id: "node", name: "Node.js", image: "node:22-alpine", category: "Runtime", description: "JavaScript runtime", defaultPorts: [PortMapping(hostPort: "3000", containerPort: "3000")], defaultVolumes: [VolumeMount(hostPath: "~/Projects/my-app", containerPath: "/app")]),
        ImagePreset(id: "python", name: "Python", image: "python:3.12-slim", category: "Runtime", description: "Python runtime", defaultPorts: [PortMapping(hostPort: "8000", containerPort: "8000")], defaultVolumes: [VolumeMount(hostPath: "~/Projects/my-app", containerPath: "/app")]),
        ImagePreset(id: "golang", name: "Go", image: "golang:1.23-alpine", category: "Runtime", description: "Go toolchain", defaultVolumes: [VolumeMount(hostPath: "~/Projects/my-app", containerPath: "/app")]),
        ImagePreset(id: "rust", name: "Rust", image: "rust:1.83-slim", category: "Runtime", description: "Rust toolchain", defaultVolumes: [VolumeMount(hostPath: "~/Projects/my-app", containerPath: "/app")]),
        ImagePreset(id: "ruby", name: "Ruby", image: "ruby:3.3-slim", category: "Runtime", description: "Ruby runtime", defaultPorts: [PortMapping(hostPort: "3000", containerPort: "3000")]),
        ImagePreset(id: "php", name: "PHP", image: "php:8.3-apache", category: "Runtime", description: "PHP with Apache", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80")]),
        ImagePreset(id: "wordpress", name: "WordPress", image: "wordpress:latest", category: "Apps", description: "CMS with Apache + PHP. Run a MySQL/MariaDB container named db on the same network. Set WORDPRESS_DB_HOST to db's IP if name lookup fails.", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/wordpress/wp-content", containerPath: "/var/www/html/wp-content")], defaultEnv: [EnvVariable(key: "WORDPRESS_DB_HOST", value: "db"), EnvVariable(key: "WORDPRESS_DB_USER", value: "wordpress"), EnvVariable(key: "WORDPRESS_DB_PASSWORD", value: "wordpress"), EnvVariable(key: "WORDPRESS_DB_NAME", value: "wordpress")]),
        ImagePreset(id: "ghost", name: "Ghost", image: "ghost:5-alpine", category: "Apps", description: "Publishing platform", defaultPorts: [PortMapping(hostPort: "2368", containerPort: "2368")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/ghost", containerPath: "/var/lib/ghost/content")]),
        ImagePreset(id: "nextcloud", name: "Nextcloud", image: "nextcloud:latest", category: "Apps", description: "Self-hosted cloud storage", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/nextcloud/data", containerPath: "/var/www/html/data"), VolumeMount(hostPath: "~/container-data/nextcloud/config", containerPath: "/var/www/html/config")]),
        ImagePreset(id: "grafana", name: "Grafana", image: "grafana/grafana:latest", category: "Monitoring", description: "Metrics dashboards", defaultPorts: [PortMapping(hostPort: "3000", containerPort: "3000")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/grafana", containerPath: "/var/lib/grafana")]),
        ImagePreset(id: "prometheus", name: "Prometheus", image: "prom/prometheus:latest", category: "Monitoring", description: "Metrics collection", defaultPorts: [PortMapping(hostPort: "9090", containerPort: "9090")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/prometheus", containerPath: "/prometheus")]),
        ImagePreset(id: "rabbitmq", name: "RabbitMQ", image: "rabbitmq:3-management-alpine", category: "Messaging", description: "Message broker with UI", defaultPorts: [PortMapping(hostPort: "5672", containerPort: "5672"), PortMapping(hostPort: "15672", containerPort: "15672")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/rabbitmq", containerPath: "/var/lib/rabbitmq")]),
        ImagePreset(id: "minio", name: "MinIO", image: "minio/minio:latest", category: "Storage", description: "S3-compatible object storage", defaultPorts: [PortMapping(hostPort: "9000", containerPort: "9000"), PortMapping(hostPort: "9001", containerPort: "9001")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/minio", containerPath: "/data")], defaultCommand: "server /data --console-address :9001"),
        ImagePreset(id: "registry", name: "Docker Registry", image: "registry:2", category: "Storage", description: "Private image registry", defaultPorts: [PortMapping(hostPort: "5000", containerPort: "5000")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/registry", containerPath: "/var/lib/registry")]),
        ImagePreset(id: "mailhog", name: "MailHog", image: "mailhog/mailhog:latest", category: "Dev Tools", description: "Email testing tool", defaultPorts: [PortMapping(hostPort: "8025", containerPort: "8025"), PortMapping(hostPort: "1025", containerPort: "1025")]),
        ImagePreset(id: "adminer", name: "Adminer", image: "adminer:latest", category: "Dev Tools", description: "Database admin UI", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "8080")]),
        ImagePreset(id: "portainer", name: "Portainer CE", image: "portainer/portainer-ce:latest", category: "Dev Tools", description: "Container management UI", defaultPorts: [PortMapping(hostPort: "9443", containerPort: "9443"), PortMapping(hostPort: "9000", containerPort: "9000")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/portainer", containerPath: "/data"), VolumeMount(hostPath: "/var/run/docker.sock", containerPath: "/var/run/docker.sock")]),
        ImagePreset(id: "jenkins", name: "Jenkins", image: "jenkins/jenkins:lts-jdk17", category: "CI/CD", description: "Automation server", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "8080"), PortMapping(hostPort: "50000", containerPort: "50000")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/jenkins", containerPath: "/var/jenkins_home")]),
        ImagePreset(id: "gitlab", name: "GitLab CE", image: "gitlab/gitlab-ce:latest", category: "CI/CD", description: "DevOps platform", defaultPorts: [PortMapping(hostPort: "8080", containerPort: "80"), PortMapping(hostPort: "8443", containerPort: "443"), PortMapping(hostPort: "2222", containerPort: "22")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/gitlab/config", containerPath: "/etc/gitlab"), VolumeMount(hostPath: "~/container-data/gitlab/logs", containerPath: "/var/log/gitlab"), VolumeMount(hostPath: "~/container-data/gitlab/data", containerPath: "/var/opt/gitlab")], defaultMemory: "4G", defaultCPUs: "4"),
        ImagePreset(id: "sonarqube", name: "SonarQube", image: "sonarqube:lts-community", category: "CI/CD", description: "Code quality platform", defaultPorts: [PortMapping(hostPort: "9000", containerPort: "9000")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/sonarqube", containerPath: "/opt/sonarqube/data")], defaultMemory: "2G"),
        ImagePreset(id: "n8n", name: "n8n", image: "n8nio/n8n:latest", category: "Apps", description: "Workflow automation", defaultPorts: [PortMapping(hostPort: "5678", containerPort: "5678")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/n8n", containerPath: "/home/node/.n8n")]),
        ImagePreset(id: "vault", name: "Vault", image: "hashicorp/vault:latest", category: "Security", description: "Secrets management", defaultPorts: [PortMapping(hostPort: "8200", containerPort: "8200")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/vault", containerPath: "/vault/file")], defaultEnv: [EnvVariable(key: "VAULT_DEV_ROOT_TOKEN_ID", value: "root")], defaultCommand: "server -dev -dev-root-token-id=root"),
        ImagePreset(id: "consul", name: "Consul", image: "hashicorp/consul:latest", category: "Infrastructure", description: "Service mesh / discovery", defaultPorts: [PortMapping(hostPort: "8500", containerPort: "8500")], defaultCommand: "agent -dev -client=0.0.0.0"),
        ImagePreset(id: "influxdb", name: "InfluxDB", image: "influxdb:2.7-alpine", category: "Database", description: "Time series database", defaultPorts: [PortMapping(hostPort: "8086", containerPort: "8086")], defaultVolumes: [VolumeMount(hostPath: "~/container-data/influxdb", containerPath: "/var/lib/influxdb2")]),
    ]

    static var categories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }

    static func presets(in category: String) -> [ImagePreset] {
        all.filter { $0.category == category }
    }
}

enum WorkspaceTabKind: Hashable, Sendable {
    case logs
    case exec
}

struct WorkspaceTab: Identifiable, Hashable, Sendable {
    let id: UUID
    let containerID: String
    let kind: WorkspaceTabKind
    var title: String

    init(
        id: UUID = UUID(),
        containerID: String,
        kind: WorkspaceTabKind,
        title: String
    ) {
        self.id = id
        self.containerID = containerID
        self.kind = kind
        self.title = title
    }
}
