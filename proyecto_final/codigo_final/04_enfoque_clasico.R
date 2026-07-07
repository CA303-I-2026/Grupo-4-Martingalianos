# 04_enfoque_clasico.R

library(readr)
library(dplyr)
library(here)

# Cargar base final limpia
datos <- read_csv(
  here("datos", "procesados", "data_centroamerica_FINAL.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)

# Paso 1: estimar la intensidad específica por causa
#
# Para cada celda (anio, sexo, pais, grupo_edad, causa), se estima:
#
#   mu_{x,t}^{(c)} = D_{x,t}^{(c)} / E_{x,t}
#
# donde:
#   D_{x,t}^{(c)} = muertes observadas por la causa c
#   E_{x,t}       = exposición de la celda demográfica
#
# En la base:
#   muertes    = D_{x,t}^{(c)}
#   exposicion = E_{x,t}
#   mu_c       = estimador de mu_{x,t}^{(c)}

datos_mu_c <- datos %>%
  mutate(
    mu_c = muertes / exposicion
  )


# Paso 2: estimar la intensidad total de decremento
#
# Para cada celda demográfica (anio, sexo, pais, grupo_edad), se suma la
# intensidad específica de todas las causas:
#
#   mu_{x,t}^{(tau)} = sum_c mu_{x,t}^{(c)}
#
# En la base:
#   mu_total = estimador de mu_{x,t}^{(tau)}
#
# Nota: la suma NO se hace por causa, porque justamente se quiere acumular
# la fuerza de todas las causas competidoras dentro de la misma celda.

datos_mu_total <- datos_mu_c %>%
  group_by(anio, sexo, pais, grupo_edad) %>%
  mutate(
    mu_total = sum(mu_c)
  ) %>%
  ungroup()


# Paso 3: calcular la probabilidad de decremento por causa
#
# Bajo el supuesto de fuerza constante dentro de la celda anual, se calcula:
#
#   q_{x,t}^{(c)}
#   =
#   [mu_{x,t}^{(c)} / mu_{x,t}^{(tau)}]
#   *
#   [1 - exp(-mu_{x,t}^{(tau)})]
#
# En la base:
#   q_c = estimador de q_{x,t}^{(c)}
#
# Interpretación:
#   - mu_c / mu_total reparte la probabilidad total de salida entre causas.
#   - 1 - exp(-mu_total) es la probabilidad total de morir por cualquier causa
#     en la celda anual.
#   - q_c es la probabilidad de decremento asociada a la causa específica c.

resultados_clasico <- datos_mu_total %>%
  mutate(
    q_c = if_else(
      mu_total > 0,
      (mu_c / mu_total) * (1 - exp(-mu_total)),
      0
    )
  )


# Guardar resultados --------------------------------------------------------

write_csv(
  resultados_clasico,
  here("datos", "procesados", "resultados_enfoque_clasico.csv")
)

# Vista rápida
if (interactive()) {
  View(resultados_clasico)
} else {
  print(utils::head(resultados_clasico))
}
