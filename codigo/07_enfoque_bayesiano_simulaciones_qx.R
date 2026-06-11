library(readr)
library(dplyr)
library(here)

# Simulacion posterior de qx,t(c)

# Lectura de los parametros_bayesianos y los datos

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

set.seed(122)

# Parametros generales

S = 10000 #cantidad de simulaciones
n_horizonte = 1 

# Unir alpha y Beta a cada fila del df de datos

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
    no_aplicable = case_when( # Casos no aplicables (de la metodologia)
      causa == "XV"  ~ sexo != "Mujer" | !(grupo_edad %in% grupos_xv),
      causa == "XVI" ~ grupo_edad != "0-4",
      TRUE ~ FALSE
    )
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
    q_c = colMeans(q_sim), # Calculamos la media de las q simuladas
  )
}

#Simulaciones

q_bayesiano <- datos_bayes %>%
  filter( # Filtramos los casos no aplicables
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

# Guardar los resultados 
write_csv(
  q_bayesiano,
  here(
    "datos", 
    "procesados", 
    "resultados_enfoque_bayesiano.csv")
)

