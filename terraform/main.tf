terraform {
    required_providers {
        yandex = {
            source = "yandex-cloud/yandex"
        }
    }
    required_version = ">= 1.3.7"
}


provider "yandex" {
    cloud_id  = "b1gc78u4m6kvppfc0jb3"
    folder_id = "b1g71nrtrft99l00rlnb"
    zone      = "ru-central1-a"
}

resource "yandex_vpc_network" "vpc" {
    name = "vpc-b1g71nrtrft99l00rlnb"
}

resource "yandex_vpc_subnet" "private_a" {
    network_id = yandex_vpc_network.vpc.id
    name       = "sn-private-a"
    zone       = "ru-central1-a"
    v4_cidr_blocks = ["10.10.0.0/16"]
}

resource "yandex_kubernetes_cluster" "zonal" {
    name        = "k8s"
    description = "Implica's devops school k8s cluster"
    network_id  = yandex_vpc_network.vpc.id

    master {
        version = 1.31
        zonal {
            subnet_id = yandex_vpc_subnet.private_a.id
            zone      = "ru-central1-a"
        }
        public_ip = true

        maintenance_policy {
            auto_upgrade = false
        }
    }

    service_account_id      = "ajeubrnv0n89aquct2pm"
    node_service_account_id = "ajeubrnv0n89aquct2pm"
    release_channel         = "RAPID"
    network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "workers" {
    cluster_id  = yandex_kubernetes_cluster.zonal.id
    name        = "workers"
    description = "K8S workers"
    version     = 1.31

    instance_template {
        platform_id = "standard-v3" # Intel Xeon Gold 6230

        network_interface {
            nat        = true
            subnet_ids = [yandex_vpc_subnet.private_a.id]
        }

        resources {
            memory = 2
            cores  = 2
        }

        boot_disk {
            type = "network-ssd"
            size = 64
        }

        scheduling_policy {
            preemptible = false
        }
    }

    scale_policy {
        fixed_scale {
            size = 1
        }
    }

    allocation_policy {
        location {
            zone = "ru-central1-a"
        }
    }

    maintenance_policy {
        auto_upgrade = false
        auto_repair  = true
    }
}

output "cluster_id" {
    value       = yandex_kubernetes_cluster.zonal.id
    description = "K8S cluster ID"
    depends_on  = [yandex_kubernetes_node_group.workers]
}

