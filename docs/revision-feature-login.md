# Auto-revisión: `feature/login` → `develop`

**Estado:** auto-revisión completada y adjunta al [PR #1](https://github.com/jonathan24-sou/Gestion-Gastos-Personales/pull/1), actualmente abierto.

## Alcance revisado

- Registro e inicio de sesión por correo con Supabase Auth.
- Validación de correo y contraseña en el cliente.
- Manejo visible de errores del proveedor y del estado de confirmación de correo.
- Continuación local sin cuenta cuando Supabase no está configurado.
- Sin contraseñas ni claves `service_role` guardadas en el código.
- Sincronización limitada al usuario autenticado y protegida por políticas RLS; los tokens los administra Supabase.
- La categoría de un presupuesto existente queda fija para preservar la clave de identidad usada en SQLite y Supabase; para cambiarla, se elimina y se crea un presupuesto nuevo.

## Comprobaciones

- `flutter analyze`: sin problemas.
- `flutter test`: pruebas de cifrado, persistencia SQLite, validación de formularios e identidad del presupuesto aprobadas.
- Configuración remota documentada en `README.md`; exige clave pública y políticas RLS antes de habilitar la sincronización.

## Hallazgo y corrección de revisión

Se identificó que cambiar la categoría durante la edición de un presupuesto podía colisionar con el ID derivado de la categoría, y que un presupuesto remoto anterior podía reaparecer en la siguiente sincronización. La corrección de `hotfix/budget-category-edit` fija la categoría al editar y añade una prueba de regresión; el flujo para cambiarla es eliminar y crear.

## Resultado

La ruta local continúa disponible si Auth no está configurado o falla. El error de Auth se presenta en pantalla y no se simula un inicio de sesión exitoso. La auto-revisión se adjunta al PR #1 de `feature/login` hacia `develop`.
