library(readr)
library(dplyr)
library(here)
library(knitr)

options(scipen = 999)

# 1. Cargar bases ----------------------------------------------------------

clasico <- read_csv(
  here("datos", "procesados", "resultados_enfoque_clasico.csv"),
  show_col_types = FALSE
)

bayesiano <- read_csv(
  here("datos", "procesados", "resultados_enfoque_bayesiano.csv"),
  show_col_types = FALSE
)

# 2. Definir llaves de comparación ----------------------------------------

llaves <- c(
  "pais",
  "anio",
  "sexo",
  "grupo_edad",
  "causa",
  "causa_grupo"
)

# 3. Unir solo las celdas comparables -------------------------------------

comparacion_q <- clasico %>%
  select(
    all_of(llaves),
    muertes,
    exposicion,
    q_clasico = q_c
  ) %>%
  inner_join(
    bayesiano %>%
      select(
        all_of(llaves),
        q_bayesiano = q_c
      ),
    by = llaves
  ) %>%
  mutate(
    diferencia_q = q_bayesiano - q_clasico,
    diferencia_abs_q = abs(diferencia_q),
    
    # DRAS: diferencia relativa absoluta simétrica
    # Está entre 0 y 2. Valores cercanos a 0 indican alta coincidencia.
    dras = if_else(
      q_clasico + q_bayesiano > 0,
      2 * diferencia_abs_q / (q_clasico + q_bayesiano),
      0
    ),
    
    q_clasico_cero = q_clasico == 0
  )

# 4. Tabla 1: discrepancia entre enfoques por causa ------------------------

tabla_01_discrepancia <- comparacion_q %>%
  group_by(causa, causa_grupo) %>%
  summarise(
    n_celdas = n(),
    mediana_dras = median(dras, na.rm = TRUE),
    p95_dras = quantile(dras, 0.95, na.rm = TRUE),
    mediana_dif_abs_q = median(diferencia_abs_q, na.rm = TRUE),
    pct_q_clasico_cero = mean(q_clasico_cero, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(p95_dras)) %>%
  mutate(
    mediana_dras = round(mediana_dras, 4),
    p95_dras = round(p95_dras, 4),
    mediana_dif_abs_q = round(mediana_dif_abs_q, 8),
    pct_q_clasico_cero = round(100 * pct_q_clasico_cero, 1)
  )

# Versión corta para reporte: no más de 8 filas
tabla_01_reporte <- tabla_01_discrepancia %>%
  slice_head(n = 8)

# 5. Guardar tabla para llamarla desde el QMD ------------------------------

write_csv(
  tabla_01_reporte,
  here("datos", "procesados", "tabla_01_discrepancia_enfoques.csv")
)

# 6. Vista rápida en consola -----------------------------------------------

#tabla_01_reporte %>%
  #kable(
   # caption = "Tabla 1. Causas ICD-10 con mayor discrepancia entre enfoque clásico y bayesiano"
  #)