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
if (any(is.na(datos$muertes)) || any(is.na(datos$exposicion))) {
  stop("Hay valores faltantes en muertes o exposicion.")
}

if (any(datos$muertes < 0)) {
  stop("La variable muertes contiene valores negativos.")
}

if (any(datos$exposicion <= 0)) {
  stop("La variable exposicion contiene valores menores o iguales a cero.")
}

# 2. Definir las celdas aplicables -----------------------------------------
# No se eliminan, en general, las celdas con cero muertes.
# Solo se excluyen ceros estructurales en dos causas particulares:
#
# XV: Embarazo, parto y puerperio
#     Se ajusta únicamente con mujeres de 10-14 a 50-54 años.
#
# XVI: Afecciones originadas en el periodo perinatal
#      Se ajusta únicamente con el grupo 0-4.

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

# 3. Log-verosimilitud marginal Poisson-Gamma ------------------------------
# D | mu ~ Poisson(E * mu)
# mu ~ Gamma(alpha, beta), con beta como parámetro de tasa.
#
# Al integrar mu:
# D ~ Binomial negativa,
# con size = alpha y media = E * alpha / beta.

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

# 4. Estimar alpha y beta para un país y una causa --------------------------
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

# 5. Estimar los hiperparámetros por país y causa ---------------------------
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

# 6. Guardar los resultados -------------------------------------------------
write_csv(
  parametros_bayesianos,
  here(
    "datos",
    "procesados",
    "parametros_bayesianos_alpha_beta.csv"
  )
)

# Simulacion posterior de qx,t(c)

set.seed(122)

# Parametros generales

S = 10000 #cantidad de simulaciones
n_horizonte = 1 

# Unir alpha y Beta a cada fila del df de datos

datos_bayes <- datos %>%
  left_join(
    parametros_bayesianos,
    by = c("pais", "causa", "causa_grupo")
  )

# funcion para simular q

simular_q_celda <- function(base_celda, S = 10000, n = 1) {
  
  mu_sim <- sapply(seq_len(nrow(base_celda)), function(j) { # se simulan S gamma por fila (causa, anio, pais y sexo)
    rgamma(
      n = S,
      shape = base_celda$alpha[j] + base_celda$muertes[j],
      rate  = base_celda$beta[j] + base_celda$exposicion[j]
    )
  })
  
  mu_total <- rowSums(mu_sim) # Sumamos todas las causas por simulacion 
  
  proporcion_causa <- mu_sim / mu_total
  prob_total <- 1 - exp(-n * mu_total)
  
  q_sim <- proporcion_causa * prob_total # Calculamos el q simulado
  
  tibble(
    causa = base_celda$causa,
    causa_grupo = base_celda$causa_grupo,
    q_media_posterior = colMeans(q_sim), # Calculamos la media de las q simuladas
    q_mediana_posterior = apply(q_sim, 2, median),
    q_li_95 = apply(q_sim, 2, quantile, probs = 0.025),
    q_ls_95 = apply(q_sim, 2, quantile, probs = 0.975)
  )
}

#Simulaciones

q_bayesiano <- datos_bayes %>%
  group_by(
    pais,
    anio,
    grupo_edad,
    sexo
  ) %>%
  group_modify(
    ~ simular_q_celda(.x, S = S, n = n_horizonte)
  ) %>%
  ungroup()

q_bayesiano

