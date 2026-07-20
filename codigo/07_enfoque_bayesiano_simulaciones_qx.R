library(readr)
library(dplyr)
library(here)

# simulación posterior de q por causa

# cargamos los hiperparámetros y la base

parametros_bayesianos <- read_csv(
  here("datos", "procesados", "parametros_bayesianos_alpha_beta.csv"),
  show_col_types = FALSE
)

datos <- read_csv(
  here(
    "datos",
    "procesados",
    "data_centroamerica_FINAL.csv"
  ),
  show_col_types = FALSE
)

# estos valores se pueden cambiar desde la terminal

semilla_bayes <- as.integer(Sys.getenv("SEMILLA_BAYES", "122"))
if (is.na(semilla_bayes)) {
  stop("SEMILLA_BAYES debe ser un entero.")
}
set.seed(semilla_bayes)

S <- as.integer(Sys.getenv("N_SIM_BAYES", "10000")) # cantidad de simulaciones
if (is.na(S) || S <= 0) {
  stop("N_SIM_BAYES debe ser un entero positivo.")
}
n_horizonte <- 1

# pegamos alpha y beta a cada fila

grupos_xv <- c(
  "10-14", "15-19", "20-24", "25-29", "30-34",
  "35-39", "40-44", "45-49", "50-54"
)

datos_bayes <- datos %>%
  left_join(
    parametros_bayesianos,
    by = c("pais", "causa", "causa_grupo")
  ) %>%
  mutate(
    no_aplicable = case_when( # casos no aplicables según la metodología
      causa == "XV"  ~ sexo != "Mujer" | !(grupo_edad %in% grupos_xv),
      causa == "XVI" ~ grupo_edad != "0-4",
      TRUE ~ FALSE
    )
  )

# simulación de q para una celda

simular_q_celda <- function(base_celda, S = 10000, n = 1) {
  
  mu_sim <- sapply(seq_len(nrow(base_celda)), function(j) { # simulamos S gamma por fila
    rgamma(
      n = S,
      shape = base_celda$alpha[j] + base_celda$muertes[j],
      rate  = base_celda$beta[j] + base_celda$exposicion[j]
    )
  })
  
  mu_total <- rowSums(mu_sim) # sumamos las causas en cada simulación
  
  proporcion_causa <- mu_sim / mu_total
  prob_total <- 1 - exp(-n * mu_total)
  
  q_sim <- proporcion_causa * prob_total # calculamos q en cada simulación
  
  tibble(
    causa = base_celda$causa,
    causa_grupo = base_celda$causa_grupo,
    q_c = colMeans(q_sim), # media de las q simuladas
  )
}

# corremos las simulaciones

q_bayesiano <- datos_bayes %>%
  filter( # quitamos los casos no aplicables
    !no_aplicable,
    !is.na(alpha),
    !is.na(beta)
  ) %>%
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

# guardamos el resumen posterior
write_csv(
  q_bayesiano,
  here(
    "datos", 
    "procesados", 
    "resultados_enfoque_bayesiano.csv")
)
