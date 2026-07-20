# Credit Campaign Analytics Dashboard

Dashboard Power BI construido desde cero para reemplazar un proceso manual
en Excel, brindando visibilidad completa del embudo de aprobación crediticia —
desde el universo inicial de clientes hasta los leads finales por campaña —
con seguimiento de cosechas a 3M y 6M.

## 📸 Dashboard preview

### Leads — Campaign summary
![Leads tab](sample_output/tab_leads.png)

### Cascada — Filter waterfall
![Cascada tab](sample_output/tab_cascada.png)

### Seguimiento — Cohort tracking
![Seguimiento tab](sample_output/tab_seguimiento.png)

---

## 🎯 Contexto de negocio

La institución gestionaba múltiples campañas crediticias mensuales (aprobados
masivos y preaprobados) a través de distintas líneas de producto: EAI,
Recurrente, Reenganche y más de 10 campañas piloto. El único seguimiento
disponible era una tabla Excel histórica con conteo de leads por campaña —
sin desglose de filtros, sin embudo de aprobación y sin seguimiento de cosechas.

Esta solución construyó la capa analítica completa desde cero:

| Antes | Después |
|-------|---------|
| Excel manual con conteo de leads | Power BI interactivo con 3 módulos analíticos |
| Sin desglose de filtros | Embudo completo: universo → filtros duros → filtros estratégicos → leads |
| Sin seguimiento de cosechas | Cosechas a 3M y 6M por campaña y cohorte |
| Actualización manual mensual (horas) | Automatizado con 3 stored procedures + proceso documentado |

---

## 🏗️ Arquitectura

```
SQL Server (BD_Creditos)
  │
  ├── SP_LEADS_REPORT          ← Normaliza datos de campaña → HAR_LEADS_RESUMEN
  ├── SP_CASCADE_SUMMARY       ← Orquesta 12+ sub-procedures → BD_CASCADAS_FINALES
  └── SP_CAMPAIGN_TRACKING     ← Calcula cosechas → FCC_SEG_CAMP_REPORTE
          │
          ▼
  Power BI Desktop (.pbix)
  ├── Pestaña Leads       — Resumen de leads por campaña (aprobados, montos, rangos de score)
  ├── Pestaña Cascada     — Embudo de filtros (filtros duros y estratégicos por campaña)
  └── Pestaña Seguimiento — Seguimiento de cohortes (cosechas 3M/6M, desembolsos, efectividad)
          │
          ▼
  Power BI Report Server  (compartido con equipos de negocios y riesgos)
```

---

## 📊 Módulos del dashboard

### Leads
Resumen de leads aprobados y evaluables por campaña, período y producto.
Incluye KPIs: total de leads, monto total aprobado, distribución por rango
de score, tipo de cliente (nuevo / recurrente) y rango de oferta.

### Cascada
Visualización del embudo de filtros por campaña. Muestra cómo el universo
inicial (12M+ clientes) se reduce a través de:
- **Filtros duros:** buró de crédito, nacionalidad, crédito grupal, base
  negativa, etc.
- **Filtros estratégicos:** reglas de elegibilidad específicas por campaña
  (frecuencia, atrasos, exclusión de productos, etc.)

Permite al equipo de riesgos identificar qué filtros generan mayor caída y
ajustar las políticas de campaña en consecuencia.

### Seguimiento
Tracker mensual de cohortes para leads aprobados y preaprobados, que muestra:
- Monto desembolsado por campaña
- Efectividad (tasa de conversión leads → desembolsos)
- Cosecha 3M y 6M (ratio de castigos a 3 y 6 meses post-desembolso)
- Ticket promedio y cantidad de desembolsos

---

## 🗄️ Stored procedures

| Archivo | Procedure | Propósito |
|---------|-----------|-----------|
| `sql/sp_leads_report.sql` | `SP_LEADS_REPORT` | Pobla HAR_LEADS_RESUMEN/REPORTE desde datos de oferta |
| `sql/sp_cascade_summary.sql` | `SP_CASCADE_SUMMARY` | Orquesta 12+ sub-procedures de cascada (2 etapas) |
| `sql/sp_campaign_tracking.sql` | `SP_CAMPAIGN_TRACKING` | Construye tabla de seguimiento de cosechas |

### Decisiones de diseño destacadas

**Normalización de nombres en SP_LEADS_REPORT:** los nombres de campaña
variaban entre períodos (ej. `'Piloto 1'` y `'Piloto 1 – Capacidad de Pago'`
referenciaban la misma campaña). Un bloque `CASE WHEN` con más de 20 mappings
estandariza todas las variantes a un código consistente, garantizando que las
comparaciones históricas sean válidas pese a los cambios de nomenclatura.

**Ejecución en 2 etapas en SP_CASCADE_SUMMARY:** la etapa 1 genera el embudo
antes de que la tabla de oferta esté completa, dando al equipo de riesgos un
punto de validación intermedio. La etapa 2 consolida los resultados finales
una vez que negocios confirma los datos de oferta.

**Herencia de filtros entre períodos:** el `MAESTRO_FILTROS` de cada mes se
inicializa copiando la configuración del mes anterior y actualizando solo los
filtros que cambiaron. Esto preserva la comparabilidad histórica y reduce el
esfuerzo manual mensual.

---

## 🛠️ Stack técnico

| Capa | Tecnología |
|------|-----------|
| Procesamiento de datos | SQL Server · Stored Procedures · T-SQL |
| BI y Visualización | Power BI Desktop · Power BI Report Server |
| Modelo de datos | Esquema estrella con tablas de staging HAR |
| Documentación | Guía de proceso en Markdown |

---

## 📸 Vista previa del dashboard

### Leads — Resumen de campaña
![Pestaña Leads](sample_output/tab_leads.png)

### Cascada — Embudo de filtros
![Pestaña Cascada](sample_output/tab_cascada.png)

### Seguimiento — Tracking de cohortes
![Pestaña Seguimiento](sample_output/tab_seguimiento.png)

---

## 📋 Proceso mensual

Ver [`docs/process_guide.md`](docs/process_guide.md) para el proceso completo
de actualización paso a paso, incluyendo puntos de validación y guía de
resolución de problemas.

---

## 📬 Contacto

**Ronaldo Chiche Surco**
[LinkedIn](https://linkedin.com/in/ronaldo-chiche) · rchiches@uni.pe
