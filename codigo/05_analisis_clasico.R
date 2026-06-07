# 05_analisis_clasico.R

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(stringr)
library(scales)

options(scipen = 999)


# ---------------------------------------------------------------------------
# 1. Cargar resultados del enfoque clásico
# ---------------------------------------------------------------------------

resultados_clasico <- read_csv(
  here("datos", "procesados", "resultados_enfoque_clasico.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)


# ---------------------------------------------------------------------------
# 2. Preparar variables generales
# ---------------------------------------------------------------------------

# Ordenar grupos etarios por límite inferior.
# Esto evita ordenamientos alfabéticos como: 0-4, 10-14, 15-19, 5-9.

orden_edades <- resultados_clasico %>%
  distinct(grupo_edad) %>%
  mutate(
    edad_inicio = parse_number(grupo_edad)
  ) %>%
  arrange(edad_inicio) %>%
  pull(grupo_edad)


# Estandarizar nombres de carpetas por país.
# Las carpetas ya existen dentro de figuras/clasico.

resultados_clasico <- resultados_clasico %>%
  mutate(
    grupo_edad = factor(grupo_edad, levels = orden_edades),
    pais_carpeta = case_when(
      pais == "Belice" ~ "belice",
      pais == "Costa Rica" ~ "costa rica",
      pais == "El Salvador" ~ "el salvador",
      pais == "Guatemala" ~ "guatemala",
      pais == "Nicaragua" ~ "nicaragua",
      pais %in% c("Panama", "Panamá") ~ "panama",
      TRUE ~ str_to_lower(pais)
    ),
    causa_grupo_wrap = str_wrap(causa_grupo, width = 35),
    q_100mil = q_c * 100000
  )


# ---------------------------------------------------------------------------
# 3. Composición causal condicionada al fallecimiento
# ---------------------------------------------------------------------------

# prop_q representa:
#
#   prop_q = q_c / sum_j q_j
#
# Es decir, dado que ocurre una muerte en la celda, qué proporción corresponde
# a cada causa.
#
# Esto es el análogo más cercano al análisis tipo Goerlich.
# No es q_c absoluto.

composicion_causal <- resultados_clasico %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  mutate(
    q_total = sum(q_c, na.rm = TRUE),
    prop_q = if_else(q_total > 0, q_c / q_total, 0)
  ) %>%
  ungroup()


# ---------------------------------------------------------------------------
# 4. Concentración causal
# ---------------------------------------------------------------------------

# Índice tipo Herfindahl:
#
#   H = sum_c prop_q^2
#
# Si H es alto, la mortalidad está concentrada en pocas causas.
# Si H es bajo, está más distribuida entre causas.

concentracion_causal <- composicion_causal %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  summarise(
    indice_concentracion = sum(prop_q^2, na.rm = TRUE),
    q_total = first(q_total),
    mu_total = first(mu_total),
    .groups = "drop"
  )


# ---------------------------------------------------------------------------
# 5. Función auxiliar de tema
# ---------------------------------------------------------------------------

tema_clasico <- function() {
  theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5),
      legend.position = "bottom",
      plot.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold")
    )
}


# ---------------------------------------------------------------------------
# 6. Gráficos por país
# ---------------------------------------------------------------------------

paises <- resultados_clasico %>%
  distinct(pais, pais_carpeta) %>%
  arrange(pais)


for (i in seq_len(nrow(paises))) {
  
  pais_actual <- paises$pais[i]
  carpeta_pais <- paises$pais_carpeta[i]
  
  ruta_figuras <- here("figuras", "clasico", carpeta_pais)
  
  datos_pais <- resultados_clasico %>%
    filter(pais == pais_actual)
  
  composicion_pais <- composicion_causal %>%
    filter(pais == pais_actual)
  
  concentracion_pais <- concentracion_causal %>%
    filter(pais == pais_actual)
  
  
  # -------------------------------------------------------------------------
  # 6.1 Causas principales del país
  # -------------------------------------------------------------------------
  
  # Para cada país se seleccionan las causas con mayor q_c promedio.
  # Esto evita que una causa sea importante globalmente, pero irrelevante
  # dentro del país que se está graficando.
  
  causas_principales_pais <- datos_pais %>%
    group_by(causa_grupo) %>%
    summarise(
      q_promedio = mean(q_c, na.rm = TRUE),
      muertes_totales = sum(muertes, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(q_promedio)) %>%
    slice_head(n = 8) %>%
    pull(causa_grupo)
  
  datos_pais_top <- datos_pais %>%
    filter(causa_grupo %in% causas_principales_pais) %>%
    mutate(
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    )
  
  composicion_pais_top <- composicion_pais %>%
    filter(causa_grupo %in% causas_principales_pais) %>%
    mutate(
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 1: q_c absoluto por edad
  # -------------------------------------------------------------------------
  #
  # Este es el gráfico principal del proyecto.
  #
  # Se grafica q_c x 100,000 para que la escala sea interpretable.
  
  grafico_01_q_edad <- datos_pais_top %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = q_100mil,
        group = causa_grupo_wrap,
        color = causa_grupo_wrap
      )
    ) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.1) +
    facet_grid(sexo ~ anio) +
    scale_y_continuous(labels = label_number(accuracy = 0.1)) +
    labs(
      title = paste0("Probabilidad absoluta de decremento por causa: ", pais_actual),
      subtitle = "q_c x 100,000. Enfoque clásico. Causas seleccionadas por mayor q_c promedio dentro del país",
      x = "Grupo etario",
      y = "q_c x 100,000",
      color = "Causa"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "01_q_absoluto_por_edad.png"),
    plot = grafico_01_q_edad,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 2: q_c absoluto por causa, con escala libre
  # -------------------------------------------------------------------------
  #
  # Este gráfico separa por causa para evitar que causas pequeñas desaparezcan
  # frente a causas con q_c mucho mayor.
  
  grafico_02_q_causa <- datos_pais_top %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = q_100mil,
        group = interaction(anio, sexo),
        color = factor(anio),
        linetype = sexo
      )
    ) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.1) +
    facet_wrap(~ causa_grupo_wrap, scales = "free_y") +
    scale_y_continuous(labels = label_number(accuracy = 0.1)) +
    labs(
      title = paste0("Variación de q_c por causa y edad: ", pais_actual),
      subtitle = "q_c x 100,000. Escala vertical libre por causa",
      x = "Grupo etario",
      y = "q_c x 100,000",
      color = "Año",
      linetype = "Sexo"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "02_q_por_causa_escala_libre.png"),
    plot = grafico_02_q_causa,
    width = 15,
    height = 10,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 3: mapa de calor de q_c
  # -------------------------------------------------------------------------
  #
  # Muestra en qué edades y causas se concentran los mayores niveles de q_c.
  
  grafico_03_heatmap_q <- datos_pais_top %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = causa_grupo_wrap,
        fill = q_100mil
      )
    ) +
    geom_tile() +
    facet_grid(sexo ~ anio) +
    scale_fill_continuous(labels = label_number(accuracy = 0.1)) +
    labs(
      title = paste0("Mapa de calor de q_c: ", pais_actual),
      subtitle = "q_c x 100,000 por grupo etario, causa, sexo y año",
      x = "Grupo etario",
      y = "Causa",
      fill = "q_c x 100,000"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "03_heatmap_q_edad_causa.png"),
    plot = grafico_03_heatmap_q,
    width = 15,
    height = 9,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 4: composición causal condicionada al fallecimiento
  # -------------------------------------------------------------------------
  #
  # Este es el gráfico tipo Goerlich.
  #
  # Muestra:
  #
  #   prop_q = q_c / sum_j q_j
  #
  # Interpretación:
  # dado que ocurre un fallecimiento en el grupo etario, qué porcentaje
  # corresponde a cada causa.
  
  grafico_04_composicion_goerlich <- composicion_pais_top %>%
    filter(anio %in% c(2015, 2018)) %>%
    group_by(anio, sexo, grupo_edad, causa_grupo_wrap) %>%
    summarise(
      prop_promedio = mean(prop_q, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = prop_promedio,
        fill = factor(anio)
      )
    ) +
    geom_col(position = "dodge") +
    facet_grid(sexo ~ causa_grupo_wrap, scales = "free_y") +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      title = paste0("Composición causal condicionada al fallecimiento: ", pais_actual),
      subtitle = "Participación porcentual dentro de la mortalidad total. Comparación 2015 y 2018",
      x = "Grupo etario",
      y = "Participación condicionada al fallecimiento",
      fill = "Año"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "04_composicion_condicionada_goerlich.png"),
    plot = grafico_04_composicion_goerlich,
    width = 18,
    height = 10,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 5: composición causal apilada por edad
  # -------------------------------------------------------------------------
  #
  # Muestra la estructura causal promedio dentro de cada grupo etario.
  # No es q_c absoluto.
  
  grafico_05_composicion_apilada <- composicion_pais_top %>%
    group_by(grupo_edad, causa_grupo_wrap) %>%
    summarise(
      prop_promedio = mean(prop_q, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = prop_promedio,
        fill = causa_grupo_wrap
      )
    ) +
    geom_col(position = "stack") +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      title = paste0("Composición causal promedio por edad: ", pais_actual),
      subtitle = "Participación relativa dentro de la probabilidad total de decremento",
      x = "Grupo etario",
      y = "Participación relativa",
      fill = "Causa"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "05_composicion_apilada_por_edad.png"),
    plot = grafico_05_composicion_apilada,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 6: cambio absoluto de q_c entre 2015 y 2018
  # -------------------------------------------------------------------------
  
  cambio_q_pais <- datos_pais %>%
    filter(anio %in% c(2015, 2018)) %>%
    select(
      pais,
      sexo,
      grupo_edad,
      causa,
      causa_grupo,
      anio,
      q_c
    ) %>%
    pivot_wider(
      names_from = anio,
      values_from = q_c,
      names_prefix = "q_"
    ) %>%
    mutate(
      cambio_q = q_2018 - q_2015,
      cambio_q_100mil = cambio_q * 100000,
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    ) %>%
    filter(causa_grupo %in% causas_principales_pais)
  
  grafico_06_cambio_q <- cambio_q_pais %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = causa_grupo_wrap,
        fill = cambio_q_100mil
      )
    ) +
    geom_tile() +
    facet_wrap(~ sexo) +
    scale_fill_continuous(labels = label_number(accuracy = 0.1)) +
    labs(
      title = paste0("Cambio absoluto de q_c entre 2015 y 2018: ", pais_actual),
      subtitle = "[q_c(2018) - q_c(2015)] x 100,000",
      x = "Grupo etario",
      y = "Causa",
      fill = "Cambio"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "06_cambio_q_2015_2018.png"),
    plot = grafico_06_cambio_q,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 7: cambio en composición causal entre 2015 y 2018
  # -------------------------------------------------------------------------
  
  cambio_prop_pais <- composicion_pais %>%
    filter(anio %in% c(2015, 2018)) %>%
    select(
      pais,
      sexo,
      grupo_edad,
      causa,
      causa_grupo,
      anio,
      prop_q
    ) %>%
    pivot_wider(
      names_from = anio,
      values_from = prop_q,
      names_prefix = "prop_"
    ) %>%
    mutate(
      cambio_prop = prop_2018 - prop_2015,
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    ) %>%
    filter(causa_grupo %in% causas_principales_pais)
  
  grafico_07_cambio_prop <- cambio_prop_pais %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = causa_grupo_wrap,
        fill = cambio_prop
      )
    ) +
    geom_tile() +
    facet_wrap(~ sexo) +
    scale_fill_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      title = paste0("Cambio en composición causal entre 2015 y 2018: ", pais_actual),
      subtitle = "prop_q(2018) - prop_q(2015)",
      x = "Grupo etario",
      y = "Causa",
      fill = "Cambio"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "07_cambio_composicion_2015_2018.png"),
    plot = grafico_07_cambio_prop,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 8: diferencia por sexo
  # -------------------------------------------------------------------------
  #
  # Muestra:
  #
  #   q_hombre - q_mujer
  
  diferencia_sexo_pais <- datos_pais %>%
    select(
      anio,
      grupo_edad,
      causa,
      causa_grupo,
      sexo,
      q_c
    ) %>%
    pivot_wider(
      names_from = sexo,
      values_from = q_c
    ) %>%
    mutate(
      diferencia_hombre_mujer = Hombre - Mujer,
      diferencia_hombre_mujer_100mil = diferencia_hombre_mujer * 100000,
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    ) %>%
    filter(causa_grupo %in% causas_principales_pais)
  
  grafico_08_diferencia_sexo <- diferencia_sexo_pais %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = causa_grupo_wrap,
        fill = diferencia_hombre_mujer_100mil
      )
    ) +
    geom_tile() +
    facet_wrap(~ anio) +
    scale_fill_continuous(labels = label_number(accuracy = 0.1)) +
    labs(
      title = paste0("Diferencia por sexo en q_c: ", pais_actual),
      subtitle = "(q_c hombres - q_c mujeres) x 100,000",
      x = "Grupo etario",
      y = "Causa",
      fill = "Diferencia"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "08_diferencia_sexo_q.png"),
    plot = grafico_08_diferencia_sexo,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 9: concentración causal
  # -------------------------------------------------------------------------
  
  grafico_09_concentracion <- concentracion_pais %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = indice_concentracion,
        group = sexo,
        color = sexo
      )
    ) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.1) +
    facet_wrap(~ anio) +
    scale_y_continuous(labels = label_number(accuracy = 0.01)) +
    labs(
      title = paste0("Concentración causal por grupo etario: ", pais_actual),
      subtitle = "Índice H = suma de participaciones relativas al cuadrado",
      x = "Grupo etario",
      y = "Índice de concentración",
      color = "Sexo"
    ) +
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "09_concentracion_causal.png"),
    plot = grafico_09_concentracion,
    width = 14,
    height = 8,
    dpi = 300
  )
  
}