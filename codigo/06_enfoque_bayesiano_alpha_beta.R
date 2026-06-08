library(readr)
library(dplyr)
library(here)

# 1. Cargar la base ---------------------------------------------------------
datos <- read_csv(
  here(
    "datos",
    "procesados",
    "data_centroamerica_FINAL.csv"
  ),
  show_col_types = FALSE
)

# Comprobaciones básicas
if (any(datos$muertes < 0, na.rm = TRUE)) {
  stop("La variable muertes contiene valores negativos.")
}

if (any(datos$exposicion <= 0, na.rm = TRUE)) {
  stop("La variable exposicion contiene valores menores o iguales a cero.")
}

if (any(is.na(datos$muertes)) || any(is.na(datos$exposicion))) {
  stop("Hay valores faltantes en muertes o exposicion.")
}

# 2. Log-verosimilitud marginal Poisson-Gamma ------------------------------
# Modelo:
#
# D | mu ~ Poisson(E * mu)
# mu ~ Gamma(alpha, beta)
#
# beta se utiliza como parámetro de tasa.
#
# Al integrar mu:
#
# D ~ Binomial negativa
#
# con:
# size = alpha
# media = E * alpha / beta

log_verosimilitud <- function(
    log_parametros,
    muertes,
    exposicion
) {
  # Se optimiza sobre log(alpha) y log(beta)
  # para garantizar que alpha y beta sean positivos.
  alpha <- exp(log_parametros[1])
  beta  <- exp(log_parametros[2])
  
  media_conteo <- exposicion * alpha / beta
  
  sum(
    dnbinom(
      x = muertes,
      size = alpha,
      mu = media_conteo,
      log = TRUE
    )
  )
}

# 3. Estimar alpha y beta para un país y una causa -------------------------
estimar_alpha_beta <- function(base_grupo) {
  
  muertes_totales <- sum(base_grupo$muertes)
  exposicion_total <- sum(base_grupo$exposicion)
  
  # Si no hay ninguna muerte, alpha y beta no pueden
  # estimarse de manera única para ese grupo.
  if (muertes_totales == 0) {
    return(
      tibble(
        alpha = NA_real_,
        beta = NA_real_
      )
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
    method = "Nelder-Mead",
    control = list(
      fnscale = -1,
      maxit = 5000,
      reltol = 1e-10
    )
  )
  
  if (ajuste$convergence != 0) {
    warning(
      "Uno de los ajustes no convergió correctamente."
    )
    
    return(
      tibble(
        alpha = NA_real_,
        beta = NA_real_
      )
    )
  }
  
  tibble(
    alpha = exp(ajuste$par[1]),
    beta = exp(ajuste$par[2])
  )
}

# 4. Estimar los hiperparámetros por país y causa --------------------------
parametros_bayesianos <- datos %>%
  group_by(
    pais,
    causa,
    causa_grupo
  ) %>%
  group_modify(
    ~ estimar_alpha_beta(.x)
  ) %>%
  ungroup() %>%
  select(
    pais,
    causa,
    causa_grupo,
    alpha,
    beta
  )

# 5. Guardar los resultados como CSV ---------------------------------------
ruta_salida <- here(
  "datos",
  "procesados",
  "parametros_bayesianos_alpha_beta.csv"
)

write_csv(
  parametros_bayesianos,
  ruta_salida
)

# 6. Mostrar resultados -----------------------------------------------------
parametros_bayesianos

message(
  "Archivo guardado en: ",
  ruta_salida
)