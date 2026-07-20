library(readr)
library(dplyr)
library(here)
library(knitr)

options(scipen = 999)

# cargamos los dos resultados

clasico <- read_csv(
  here("datos", "procesados", "resultados_enfoque_clasico.csv"),
  show_col_types = FALSE
)

bayesiano <- read_csv(
  here("datos", "procesados", "resultados_enfoque_bayesiano.csv"),
  show_col_types = FALSE
)

# llaves que identifican una celda

llaves <- c(
  "pais",
  "anio",
  "sexo",
  "grupo_edad",
  "causa",
  "causa_grupo"
)

# cruzamos únicamente las celdas comparables

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
    
# DRAS va de 0 a 2; cerca de cero significa mayor coincidencia
    dras = if_else(
      q_clasico + q_bayesiano > 0,
      2 * diferencia_abs_q / (q_clasico + q_bayesiano),
      0
    ),
    
    q_clasico_cero = q_clasico == 0
  )

# discrepancia entre enfoques por causa

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

# el informe usa una versión de ocho filas
tabla_01_reporte <- tabla_01_discrepancia %>%
  slice_head(n = 8)

# guardamos la tabla que lee la bitácora

write_csv(
  tabla_01_reporte,
  here("datos", "procesados", "tabla_01_discrepancia_enfoques.csv")
)

# una mirada rápida en consola

# para D_pi comparamos el vector completo pi_c = q_c / sum_j q_j

comparacion_pi <- comparacion_q %>%
  group_by(pais, anio, sexo, grupo_edad) %>%
  mutate(
    q_total_clasico = sum(q_clasico, na.rm = TRUE),
    q_total_bayesiano = sum(q_bayesiano, na.rm = TRUE),
    
    pi_clasico = if_else(
      q_total_clasico > 0,
      q_clasico / q_total_clasico,
      NA_real_
    ),
    
    pi_bayesiano = if_else(
      q_total_bayesiano > 0,
      q_bayesiano / q_total_bayesiano,
      NA_real_
    ),
    
    diferencia_abs_pi = abs(pi_bayesiano - pi_clasico)
  ) %>%
  ungroup()

# distancia total entre composiciones causales

tabla_02_composicion <- comparacion_pi %>%
  group_by(pais, anio, sexo, grupo_edad) %>%
  summarise(
    d_pi = 0.5 * sum(diferencia_abs_pi, na.rm = TRUE),
    q_total_clasico = first(q_total_clasico),
    q_total_bayesiano = first(q_total_bayesiano),
    causa_dom_clasico = causa[which.max(pi_clasico)],
    causa_dom_bayesiano = causa[which.max(pi_bayesiano)],
    misma_causa_dominante = causa_dom_clasico == causa_dom_bayesiano,
    .groups = "drop"
  ) %>%
  arrange(desc(d_pi)) %>%
  mutate(
    d_pi = round(d_pi, 4),
    q_total_clasico = round(q_total_clasico, 8),
    q_total_bayesiano = round(q_total_bayesiano, 8),
    misma_causa_dominante = if_else(
      misma_causa_dominante,
      "Sí",
      "No"
    )
  )

# otra vez dejamos ocho filas para el informe
tabla_02_reporte <- tabla_02_composicion %>%
  filter(
    !is.na(pais),
    !is.na(anio),
    !is.na(sexo),
    !is.na(grupo_edad),
    !is.na(d_pi)
  ) %>%
  slice_head(n = 8)

# guardamos la segunda tabla

write_csv(
  tabla_02_reporte,
  here("datos", "procesados", "tabla_02_composicion_causal.csv")
)

# una mirada rápida en consola
