# Módulo Terraform: Azure Managed Redis (AMR) con ACL

Módulo Terraform que aprovisiona **Azure Managed Redis (AMR)** con autenticación
por **Microsoft Entra ID** y asignaciones de política de acceso a datos (ACL,
*Public Preview*).

## Introducción

Azure Managed Redis (AMR) es el reemplazo de **Azure Cache for Redis Enterprise**,
que está en proceso de retirada. Este módulo crea un clúster AMR usando el SKU
`Balanced_B0` por defecto y configura el control de acceso mediante listas de
control de acceso (ACL) enlazadas a identidades de Microsoft Entra ID.

El módulo se apoya en el provider **`azapi`** porque `azurerm` todavía **no**
expone el recurso `accessPolicyAssignments` necesario para la ACL en preview.

Recursos aprovisionados:

- **`redisEnterprise`** — clúster AMR (API `2025-07-01`). Requiere
  `publicNetworkAccess` habilitado.
- **`databases/default`** — base de datos `default` del clúster (API `2025-07-01`).
- **`databases/accessPolicyAssignments`** — asignaciones de ACL (Public Preview,
  API `2025-08-01-preview`).

La autenticación es por Entra ID: `access_keys_authentication = false` por defecto.

## Requisitos previos

- **Cuenta de Azure** con sesión iniciada:
  ```bash
  az login
  ```
- **Terraform** `>= 1.5.0`.
- **Provider azapi** `>= 2.0.0` (se instala automáticamente en `terraform init`).
- Permisos para crear `Microsoft.Cache/redisEnterprise` y un grupo de recursos.

## Estructura del módulo

```
modules/azure-managed-redis/
  versions.tf    # required_version y provider azapi
  variables.tf   # variables de entrada
  main.tf        # cluster, database "default", accessPolicyAssignments
  outputs.tf     # salidas
examples/basic/
  main.tf        # ejemplo de uso completo
```

## Variables

| Variable | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `name` | `string` | — (obligatorio) | Nombre del clúster Azure Managed Redis. |
| `resource_group_id` | `string` | — (obligatorio) | ID del grupo de recursos donde se crea el clúster. |
| `location` | `string` | `westeurope` | Región de Azure. |
| `sku_name` | `string` | `Balanced_B0` | SKU de AMR (p. ej. `Balanced_B0`, `MemoryOptimized_M10`, `ComputeOptimized_X5`). |
| `high_availability` | `bool` | `true` | Habilita alta disponibilidad. |
| `client_protocol` | `string` | `Encrypted` | Protocolo de conexión: `Encrypted` (TLS) o `Plaintext`. |
| `access_keys_authentication` | `bool` | `false` | Permite autenticación por clave. Deshabilitado para forzar Entra ID. |
| `access_policy_assignments` | `map(object)` | `{}` | Asignaciones ACL. Mapa de nombre → `{ access_policy_name = "default", user_object_id }`. |
| `tags` | `map(string)` | `{}` | Etiquetas de recurso. |

> El nombre de cada `accessPolicyAssignment` (la clave del mapa) debe ser
> **alfanumérico**: `^[A-Za-z0-9]{1,60}$`.

## Salidas

| Salida | Descripción |
|---|---|
| `cluster_id` | ID del recurso del clúster Managed Redis. |
| `hostname` | Hostname del clúster. |
| `port` | Puerto de Redis (10000). |
| `access_policy_assignment_ids` | IDs de las asignaciones de política de acceso ACL. |

## Uso

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars   # edita subscription_id, location, name_prefix
terraform init
terraform plan
terraform apply
```

> Define tu `subscription_id` en `terraform.tfvars` (o exporta
> `TF_VAR_subscription_id` / `ARM_SUBSCRIPTION_ID`). No se incluye ninguna
> suscripción por defecto.

El ejemplo crea un grupo de recursos, un clúster AMR `Balanced_B0` y asigna la
política `default` al objectId de la identidad actual de Entra:

```hcl
module "redis" {
  source            = "../../modules/azure-managed-redis"
  name              = "amraclre${substr(md5(azurerm_resource_group.rg.id), 0, 6)}"
  resource_group_id = azurerm_resource_group.rg.id
  location          = "swedencentral"
  sku_name          = "Balanced_B0"
  high_availability = false

  access_policy_assignments = {
    "currentuser" = {
      access_policy_name = "default"
      user_object_id     = data.azurerm_client_config.current.object_id
    }
  }
}
```

> El aprovisionamiento del clúster tarda **~7 minutos**.

## Verificación de la ACL

Tras el `apply`, comprueba las asignaciones de política de acceso vía REST:

```bash
az rest --method get \
  --url "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG>/providers/Microsoft.Cache/redisEnterprise/<CLUSTER>/databases/default/accessPolicyAssignments?api-version=2025-08-01-preview"
```

Deberías ver la asignación `currentuser` con `accessPolicyName: default` y el
`objectId` de tu identidad de Entra.

## Limpieza

```bash
cd examples/basic
terraform destroy
```

## Notas y limitaciones de la preview

- **Capacidad por región**: `Balanced_B0` **no tenía capacidad** en
  `westeurope`, `northeurope` ni `eastus`. Sí había capacidad en
  **`swedencentral`** (región usada por el ejemplo). Selecciona la región según
  disponibilidad.
- **ACL en Public Preview**: actualmente solo se soporta la política `default`,
  asignada a un `objectId` de Microsoft Entra. La API es
  `2025-08-01-preview`.
- El nombre de la `accessPolicyAssignment` debe ser alfanumérico
  (`^[A-Za-z0-9]{1,60}$`).
- Se usa `azapi` porque `azurerm` aún no expone `accessPolicyAssignments`.
- Validado en vivo (despliegue + verificación de ACL + `destroy`) sobre una
  suscripción de pruebas de Azure.
