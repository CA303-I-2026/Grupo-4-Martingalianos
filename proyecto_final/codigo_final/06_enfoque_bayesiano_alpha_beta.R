library(readr)
library(dplyr)
library(here)

# cargamos la base final
datos <- read_csv(
  here(
    "datos",
    "procesados",
    "data_centroamerica_FINAL.csv"
  ),
  show_col_types = FALSE
)

# comprobaciones básicas antes de ajustar
if (any(is.na(datos$muertes)) || any(is.na(datos$exposicion))) {
  stop("Hay valores faltantes en muertes o exposicion.")
}

if (any(datos$muertes < 0)) {
  stop("La variable muertes contiene valores negativos.")
}

if (any(datos$exposicion <= 0)) {
  stop("La variable exposicion contiene valores menores o iguales a cero.")
}

# dejamos los ceros observados y quitamos solo dos casos estructurales
#
# XV: embarazo, parto y puerperio, solo en mujeres de 10-14 a 50-54
#
# XVI: afecciones perinatales, solo para el grupo 0-4

edades_maternas <- c(
  "10-14",
  "15-19",
  "20-24",
  "25-29",
  "30-34",
  "35-39",
  "40-44",
  "45-49",
  "50-54"
)

datos_ajuste <- datos %>%
  filter(
    !(causa %in% c("XV", "XVI")) |
      (
        causa == "XV" &
          sexo == "Mujer" &
          grupo_edad %in% edades_maternas
      ) |
      (
        causa == "XVI" &
          grupo_edad == "0-4"
      )
  )

# log-verosimilitud marginal Poisson-Gamma
# D | mu ~ Poisson(E * mu)
# mu ~ Gamma(alpha, beta), con beta como parámetro de tasa.
#
# al integrar mu queda una binomial negativa con media E * alpha / beta

log_verosimilitud <- function(
    log_parametros,
    muertes,
    exposicion
) {
  alpha <- exp(log_parametros[1])
  beta  <- exp(log_parametros[2])
  
  media <- exposicion * alpha / beta
  
  sum(
    dnbinom(
      x = muertes,
      size = alpha,
      mu = media,
      log = TRUE
    )
  )
}

# ajuste de alpha y beta para cada país y causa
estimar_alpha_beta <- function(base_grupo, llave) {
  muertes_totales  <- sum(base_grupo$muertes)
  exposicion_total <- sum(base_grupo$exposicion)
  
  if (muertes_totales == 0) {
    stop(
      "No se pueden estimar alpha y beta para ",
      llave$pais,
      " - causa ",
      llave$causa,
      ": todas las muertes son cero."
    )
  }
  
  tasa_global <- muertes_totales / exposicion_total
  
  ajuste <- optim(
    par = log(
      c(
        alpha = 1,
        beta = 1 / tasa_global
      )
    ),
    fn = log_verosimilitud,
    muertes = base_grupo$muertes,
    exposicion = base_grupo$exposicion,
    control = list(
      fnscale = -1,
      maxit = 5000,
      reltol = 1e-10
    )
  )
  
  if (ajuste$convergence != 0) {
    stop(
      "El ajuste no convergió para ",
      llave$pais,
      " - causa ",
      llave$causa,
      "."
    )
  }
  
  tibble(
    alpha = exp(ajuste$par[1]),
    beta = exp(ajuste$par[2])
  )
}

# corremos el ajuste para todas las combinaciones
parametros_bayesianos <- datos_ajuste %>%
  group_by(
    pais,
    causa,
    causa_grupo
  ) %>%
  group_modify(
    ~ estimar_alpha_beta(.x, .y)
  ) %>%
  ungroup() %>%
  select(
    pais,
    causa,
    causa_grupo,
    alpha,
    beta
  )

# guardamos los hiperparámetros
write_csv(
  parametros_bayesianos,
  here(
    "datos",
    "procesados",
    "parametros_bayesianos_alpha_beta.csv"
  )
)
