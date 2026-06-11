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
    diferencia = q_bayesiano - q_clasico,
    diferencia_abs = abs(diferencia),
    diferencia_relativa = if_else(
      q_clasico > 0,
      diferencia_abs / q_clasico,
      NA_real_
    )
  )

# 4. Resumen general clásico vs bayesiano ---------------------------------

resumen_comparacion <- comparacion_q %>%
  summarise(
    celdas_comparables = n(),
    celdas_dif_menor_0001 = sum(diferencia_abs < 0.0001),
    proporcion_dif_menor_0001 = mean(diferencia_abs < 0.0001),
    mediana_diferencia_abs = median(diferencia_abs),
    media_diferencia_abs = mean(diferencia_abs),
    max_diferencia_abs = max(diferencia_abs)
  )

resumen_comparacion %>%
  mutate(
    proporcion_dif_menor_0001 = round(100 * proporcion_dif_menor_0001, 1),
    mediana_diferencia_abs = round(mediana_diferencia_abs, 8),
    media_diferencia_abs = round(media_diferencia_abs, 8),
    max_diferencia_abs = round(max_diferencia_abs, 8)
  ) %>%
  kable(
    caption = "Resumen de comparación entre enfoque clásico y bayesiano"
  )
