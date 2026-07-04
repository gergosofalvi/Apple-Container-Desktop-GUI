//
//  apple_containers_guiTests.swift
//  apple.containers.guiTests
//

import Foundation
import Testing
@testable import apple_containers_gui

@Suite(.serialized)
struct ContainerComposeTests {
    @Test func decodeMinimalService() throws {
        let yaml = """
        services:
          app:
            image: nginx:alpine
        """
        let document = try ContainerComposeYAML.decode(yaml)
        #expect(document.services.count == 1)
        #expect(document.services["app"]?.image == "nginx:alpine")
    }

    @Test func roundTripSingleService() throws {
        let service = ContainerComposeService(
            image: "wordpress:latest",
            containerName: "wordpress",
            workingDir: "/var/www/html",
            ports: ["8080:80"],
            volumes: ["/Users/test/wordpress/wp-content:/var/www/html/wp-content"],
            environment: [
                "WORDPRESS_DB_HOST": "db",
                "WORDPRESS_DB_PASSWORD": "secret",
            ],
            command: "apache2-foreground",
            cpus: "2",
            memLimit: "1G"
        )

        let document = ContainerComposeDocument(services: ["wordpress": service])
        let yaml = ContainerComposeYAML.encode(document)
        let decoded = try ContainerComposeYAML.decode(yaml)

        #expect(decoded.services.count == 1)

        let decodedService = try #require(decoded.services["wordpress"])
        #expect(decodedService.image == service.image)
        #expect(decodedService.containerName == service.containerName)
        #expect(decodedService.workingDir == service.workingDir)
        #expect(decodedService.ports == service.ports)
        #expect(decodedService.volumes == service.volumes)
        #expect(decodedService.environment == service.environment)
        #expect(decodedService.command == service.command)
        #expect(decodedService.cpus == service.cpus)
        #expect(decodedService.memLimit == service.memLimit)
    }

    @Test func importMapsToCreateForm() throws {
        let yaml = """
        services:
          app:
            image: nginx:alpine
            container_name: my-nginx
            working_dir: /usr/share/nginx/html
            ports:
              - "8080:80/tcp"
            volumes:
              - /tmp/html:/usr/share/nginx/html:ro
            environment:
              FOO: bar
            command: nginx -g 'daemon off;'
            cpus: "1"
            mem_limit: 512M
        """

        let document = try ContainerComposeYAML.decode(yaml)
        let service = try #require(document.services["app"])
        let form = service.toCreateContainerForm(serviceName: "app")

        #expect(form.image == "nginx:alpine")
        #expect(form.name == "my-nginx")
        #expect(form.workdir == "/usr/share/nginx/html")
        #expect(form.command == "nginx -g 'daemon off;'")
        #expect(form.cpus == "1")
        #expect(form.memory == "512M")
        #expect(form.portMappings.count == 1)
        #expect(form.portMappings[0].hostPort == "8080")
        #expect(form.portMappings[0].containerPort == "80")
        #expect(form.volumeMounts.count == 1)
        #expect(form.volumeMounts[0].readOnly == true)
        #expect(form.envVars.contains(where: { $0.key == "FOO" && $0.value == "bar" }))
    }

    @Test func environmentListFormat() throws {
        let yaml = """
        services:
          db:
            image: postgres:16-alpine
            environment:
              - POSTGRES_PASSWORD=secret
              - POSTGRES_USER=app
        """

        let document = try ContainerComposeYAML.decode(yaml)
        let service = try #require(document.services["db"])
        #expect(service.environment["POSTGRES_PASSWORD"] == "secret")
        #expect(service.environment["POSTGRES_USER"] == "app")
    }
}
