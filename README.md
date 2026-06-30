# Módulo Terraform: Azure Managed Redis (AMR) con ACL

Módulo Terraform que aprovisiona **Azure Managed Redis (AMR)** con autenticación
por **Microsoft Entra ID** y asignaciones de política de acceso a datos (ACL,
*Public Preview*).

## Introducción

Azure Managed Redis (AMR) es el reemplazo de **Azure Cache for Redis Enterprise**,
que está en proceso de retirada. Este módulo crea un clúster AMR usando el SKU
`Balanced_B0` por defecto y configura el control de acceso mediante listas de
control de acceso (ACL) enlazadas a identidades de Microsoft Entra ID.

El módulo se apoya en el provider **`azapi`** para el clúster, la base de datos y
las `accessPolicyAssignments` (que `azurerm` todavía **no** expone para la ACL en
preview), y en **`azurerm`** para el private endpoint opcional.

Recursos aprovisionados:

- **`redisEnterprise`** — clúster AMR (API `2025-07-01`). El acceso de red
  público (`publicNetworkAccess`) es **configurable** (`Enabled`/`Disabled`).
- **`databases/default`** — base de datos `default` del clúster (API `2025-07-01`).
- **`databases/accessPolicyAssignments`** — asignaciones de ACL (Public Preview,
  API `2025-08-01-preview`).
- **`azurerm_private_endpoint`** *(opcional)* — private endpoint contra el clúster
  (subrecurso/groupId `redisEnterprise`) para conectividad privada.

La autenticación es por Entra ID: `access_keys_authentication = false` por defecto.

## Preguntas frecuentes (FAQ)

1. **¿Se pueden crear más políticas además de `default`, con distinta
   granularidad?** Hoy **no**. El API de la preview de ACL de AMR
   (`2025-08-01-preview`) **solo soporta la política `default`** (acceso total de
   plano de datos) — la propia documentación de Microsoft lo indica: *"Only
   'default' policy is supported for now"*. Todavía **no** existen políticas de
   datos granulares personalizadas (p. ej. solo-lectura) para AMR. Lo que **sí**
   se puede hacer es crear **varias asignaciones** (`access_policy_assignments`),
   cada una enlazando un principal de Entra distinto (usuario, grupo, *managed
   identity* o *service principal*). El campo `access_policy_name` queda
   parametrizado para no tener que tocar el módulo cuando Azure amplíe la preview.

2. **¿Es obligatorio el tráfico público? ¿Sirve con private endpoints?** **No es
   obligatorio.** `public_network_access` es configurable y puede ponerse en
   `Disabled`. El módulo soporta crear un **private endpoint** (subrecurso
   `redisEnterprise`, zona DNS privada `privatelink.redis.azure.net`). El ejemplo
   despliega por defecto el clúster **sin tráfico público**, accesible solo por
   private endpoint.

3. **¿Se puede desplegar en Spain Central (latencias)?** **Sí.** Spain Central
   (`spaincentral`) figura como región soportada para `Microsoft.Cache/redisEnterprise`
   en el plano de control de Azure. El ejemplo usa `spaincentral` por defecto.
   Verifica la capacidad del SKU concreto (`Balanced_B0`) en el `apply`, ya que la
   disponibilidad por SKU/región puede variar durante la preview.

## Requisitos previos

- **Cuenta de Azure** con sesión iniciada:
  ```bash
  az login
  ```
- **Terraform** `>= 1.5.0`.
- **Provider azapi** `>= 2.0.0` y **azurerm** `>= 4.0.0` (se instalan
  automáticamente en `terraform init`).
- Permisos para crear `Microsoft.Cache/redisEnterprise` y un grupo de recursos.

## Estructura del módulo

```
modules/azure-managed-redis/
  versions.tf    # required_version y providers azapi + azurerm
  variables.tf   # variables de entrada
  main.tf        # cluster, database "default", accessPolicyAssignments, private endpoint
  outputs.tf     # salidas
examples/basic/
  main.tf        # ejemplo: Spain Central + private endpoint + ACL múltiple
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
| `public_network_access` | `string` | `Enabled` | Acceso de red público: `Enabled` o `Disabled`. Usa `Disabled` con private endpoints. |
| `access_keys_authentication` | `bool` | `false` | Permite autenticación por clave. Deshabilitado para forzar Entra ID. |
| `access_policy_assignments` | `map(object)` | `{}` | Asignaciones ACL. Mapa de nombre → `{ access_policy_name = "default", user_object_id }`. Admite **varias** asignaciones a distintos principals de Entra. |
| `private_endpoint` | `object` | `null` | Private endpoint opcional: `{ subnet_id, name?, private_dns_zone_ids? }`. Subrecurso `redisEnterprise`. |
| `tags` | `map(string)` | `{}` | Etiquetas de recurso. |

> El nombre de cada `accessPolicyAssignment` (la clave del mapa) debe ser
> **alfanumérico**: `^[A-Za-z0-9]{1,60}$`.
>
> El módulo valida que `access_policy_name` sea `"default"`, ya que es la única
> política soportada hoy por la preview. Actualiza esa validación cuando Azure
> añada más políticas integradas.

## Salidas

| Salida | Descripción |
|---|---|
| `cluster_id` | ID del recurso del clúster Managed Redis. |
| `hostname` | Hostname del clúster. |
| `port` | Puerto de Redis (10000). |
| `access_policy_assignment_ids` | IDs de las asignaciones de política de acceso ACL. |
| `public_network_access` | Estado del acceso de red público (`Enabled`/`Disabled`). |
| `private_endpoint_id` | ID del private endpoint (o `null` si no se crea). |
| `private_endpoint_ip` | IP privada asignada al private endpoint (o `null`). |

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

El ejemplo crea un grupo de recursos en **Spain Central**, un clúster AMR
`Balanced_B0` **sin tráfico público** (accesible solo por private endpoint) y
asigna la política `default` al objectId de la identidad actual de Entra.
Puedes añadir un principal adicional (`extra_principal_object_id`) para
demostrar varias asignaciones, o desactivar el private endpoint con
`enable_private_networking = false`:

```hcl
module "redis" {
  source            = "../../modules/azure-managed-redis"
  name              = "amraclre${substr(md5(azurerm_resource_group.rg.id), 0, 6)}"
  resource_group_id = azurerm_resource_group.rg.id
  location          = "spaincentral"
  sku_name          = "Balanced_B0"
  high_availability = false

  public_network_access = "Disabled"

  private_endpoint = {
    subnet_id            = azurerm_subnet.pe.id
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id] # privatelink.redis.azure.net
  }

  access_policy_assignments = {
    "currentuser" = {
      access_policy_name = "default"
      user_object_id     = data.azurerm_client_config.current.object_id
    }
    "appprincipal" = {
      access_policy_name = "default"
      user_object_id     = var.extra_principal_object_id
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

- **Región**: `spaincentral` figura como región soportada para
  `Microsoft.Cache/redisEnterprise` en el plano de control de Azure (verificado
  con `az provider show`). La **capacidad por SKU/región** puede variar durante la
  preview: en pruebas previas `Balanced_B0` no tenía capacidad en `westeurope`,
  `northeurope` ni `eastus`, y sí en `swedencentral`. Confirma la capacidad de tu
  SKU en `terraform apply` o elige una región alternativa si falla.
- **ACL en Public Preview**: actualmente **solo** se soporta la política
  `default` (acceso total de datos), asignada a un `objectId` de Microsoft Entra
  (usuario, grupo, *managed identity* o *service principal*). **No** hay aún
  políticas granulares custom (p. ej. solo-lectura). Se pueden crear **varias
  asignaciones** a distintos principals. API `2025-08-01-preview`.
- **Tráfico público / private endpoints**: `public_network_access` es
  configurable. Con `Disabled` + `private_endpoint`, el clúster es accesible solo
  por private endpoint (subrecurso `redisEnterprise`, zona DNS privada
  `privatelink.redis.azure.net`).
- El nombre de la `accessPolicyAssignment` debe ser alfanumérico
  (`^[A-Za-z0-9]{1,60}$`).
- Se usa `azapi` para el clúster, la base de datos y las `accessPolicyAssignments`
  (que `azurerm` aún no expone); el private endpoint usa `azurerm_private_endpoint`.
- Validado con `terraform validate` y `terraform fmt`. El despliegue de ACL se
  validó en vivo (despliegue + verificación de ACL + `destroy`) sobre una
  suscripción de pruebas de Azure.
