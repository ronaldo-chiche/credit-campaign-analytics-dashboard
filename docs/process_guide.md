# Monthly Update Process Guide
## Credit Campaign Analytics Dashboard

This document describes the monthly refresh process for the dashboard.
All steps must be executed in the order shown.

---

## Prerequisites

Verify the filter master table is up to date before starting:

```sql
SELECT MAX(periodo) FROM dbo.Maestro_campañas
```

---

## Step 1 — Update the filter master table (MAESTRO_FILTROS)

Coordinate with the **business analyst** to confirm whether any new filters
have been added to any campaign in the current period.

- **If there are new filters:** add them manually to `MAESTRO_FILTROS` before
  running the procedure.
- **If no changes:** the procedure copies the previous month's filters
  automatically.

```sql
DECLARE @PERIODO VARCHAR(6) = '202601'

DELETE FROM MAESTRO_FILTROS
    WHERE PERIODO = @PERIODO

INSERT INTO MAESTRO_FILTROS
SELECT @PERIODO, ORDEN_TIPO_FILTRO, TIPO_FILTRO, ORDEN_TIPO_CAMPAÑA,
       TIPO_CAMPAÑA, ORDEN_CAMPAÑA, CAMPAÑA, ORDEN_FILTRO, FILTRO, NOMBRE, VIGENCIA
FROM MAESTRO_FILTROS
WHERE PERIODO = CONVERT(VARCHAR(6), DATEADD(MONTH,-1, CAST(@PERIODO+'01' AS DATE)), 112)
```

---

## Step 2 — Run Cascade Stage 1

```sql
EXEC dbo.SP_CASCADE_SUMMARY '202601', 1
```

This executes:
- `SP_CASCADAS_FILTROS_KILLER` and `SP_CASCADAS_FILTROS_DUROS`
- All 12 campaign-level cascade sub-procedures (EAI, Recurrente, Piloto 1–9,
  Nuevos, Evaluables, Blindaje, Ataque)

---

## Step 3 — Validate cascade and update Power BI (local)

- Open the `.pbix` file in Power BI Desktop.
- Refresh the **BD_CASCADAS_FINALES** data source connection.
- Review the Cascada tab with the **credit risk analyst** to confirm:
  - Filter waterfall volumes are consistent with prior periods.
  - Any significant drop-off in a filter stage has a documented business reason.

---

## Step 4 — Wait for offer table refresh

The **business analyst** populates the offer table (`OfertaCamp`) with the
current period's approved amounts and limits.

Once confirmed, run the Leads procedure:

```sql
EXEC dbo.SP_LEADS_REPORT '202601'
```

---

## Step 5 — Run Cascade Stage 2

```sql
EXEC dbo.SP_CASCADE_SUMMARY '202601', 2
```

Stage 2 consolidates the cascade outputs now that the offer table is complete.

---

## Step 6 — Full Power BI refresh

Refresh all data source connections in Power BI Desktop.

**Validation checkpoint:** confirm that the total leads in the Cascada tab
match the totals shown in the Leads tab for the same period.

---

## Step 7 — Update the Seguimiento tab

```sql
EXEC dbo.SP_CAMPAIGN_TRACKING '202601'
```

After running, refresh the **SEGUIMIENTO** data source in Power BI and verify:
- Data for the latest period is present.
- The cosecha 3M and 6M shading columns highlight the correct periods.

---

## Step 8 — Publish to report server

Save the updated `.pbix` and coordinate with the **BI administrator** to
publish the updated report to the shared Power BI Report Server.

---

## Troubleshooting

| Issue | Likely cause | Action |
|---|---|---|
| Cascada leads ≠ Leads tab totals | Offer table not yet refreshed | Re-run Steps 4–6 |
| Missing current period in Seguimiento | SP not executed for new period | Run Step 7 |
| New campaign not appearing in Cascada | Missing entry in MAESTRO_FILTROS | Add manually (Step 1) |
| Filter count changed unexpectedly | New filter added by business | Validate with credit risk analyst |
