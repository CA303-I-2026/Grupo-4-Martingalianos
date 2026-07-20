library(readr)
library(dplyr)
library(here)

# cargamos la base que dejó la limpieza
datos <- read_csv(
  here("datos", "procesados", "data_centroamerica_FINAL.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)

# intensidad específica por causa para cada celda
#
#   mu_{x,t}^{(c)} = D_{x,t}^{(c)} / E_{x,t}
#
# D son las muertes observadas y E es la exposición

datos_mu_c <- datos %>%
  mutate(
    mu_c = muertes / exposicion
  )


# la intensidad total suma todas las causas de la misma celda
#
#   mu_{x,t}^{(tau)} = sum_c mu_{x,t}^{(c)}

datos_mu_total <- datos_mu_c %>%
  group_by(anio, sexo, pais, grupo_edad) %>%
  mutate(
    mu_total = sum(mu_c)
  ) %>%
  ungroup()


# con fuerza constante dentro del año, calculamos q por causa
#
#   q_{x,t}^{(c)}
#   =
#   [mu_{x,t}^{(c)} / mu_{x,t}^{(tau)}]
#   *
#   [1 - exp(-mu_{x,t}^{(tau)})]
#
# mu_c / mu_total reparte la probabilidad total entre las causas

resultados_clasico <- datos_mu_total %>%
  mutate(
    q_c = if_else(
      mu_total > 0,
      (mu_c / mu_total) * (1 - exp(-mu_total)),
      0
    )
  )


# guardamos los resultados clásicos

write_csv(
  resultados_clasico,
  here("datos", "procesados", "resultados_enfoque_clasico.csv")
)

# una mirada rápida en consola
if (interactive()) {
  View(resultados_clasico)
} else {
  print(utils::head(resultados_clasico))
}
