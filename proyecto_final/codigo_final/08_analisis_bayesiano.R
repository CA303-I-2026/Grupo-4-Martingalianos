# 08_analisis_bayesiano.R

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(stringr)
library(scales)
library(ggsci)

options(scipen = 999)


# ---------------------------------------------------------------------------
# 1. Cargar resultados del enfoque bayesiano
# ---------------------------------------------------------------------------

resultados_bayesiano <- read_csv(
  here("datos", "procesados", "resultados_enfoque_bayesiano.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)


# Solo se contrastan 2015 y 2018

anios_comparacion <- c(2015, 2018)

resultados_bayesiano <- resultados_bayesiano %>%
  filter(anio %in% anios_comparacion)


# ---------------------------------------------------------------------------
# 2. Funciones auxiliares
# ---------------------------------------------------------------------------

etiqueta_pct_directa <- function(x, decimales = 2) {
  x_fmt <- format(
    round(x, decimales),
    nsmall = decimales,
    trim = TRUE,
    scientific = FALSE
  )
  
  x_fmt <- sub("(\\.\\d*?)0+$", "\\1", x_fmt)
  x_fmt <- sub("\\.$", "", x_fmt)
  
  paste0(x_fmt, "%")
}


etiqueta_pct_proporcion <- function(x, decimales = 1) {
  x <- x * 100
  
  x_fmt <- format(
    round(x, decimales),
    nsmall = decimales,
    trim = TRUE,
    scientific = FALSE
  )
  
  x_fmt <- sub("(\\.\\d*?)0+$", "\\1", x_fmt)
  x_fmt <- sub("\\.$", "", x_fmt)
  
  paste0(x_fmt, "%")
}


tema_bayesiano <- function() {
  theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5),
      legend.position = "bottom",
      plot.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold"),
      legend.title = element_text(face = "bold")
    )
}


# ---------------------------------------------------------------------------
# 3. Preparar variables generales
# ---------------------------------------------------------------------------

orden_edades <- resultados_bayesiano %>%
  distinct(grupo_edad) %>%
  mutate(
    edad_inicio = parse_number(grupo_edad)
  ) %>%
  arrange(edad_inicio) %>%
  pull(grupo_edad)


resultados_bayesiano <- resultados_bayesiano %>%
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
    q_porcentaje = q_c * 100
  )


# ---------------------------------------------------------------------------
# 4. Composición causal condicionada al fallecimiento
# ---------------------------------------------------------------------------

# prop_q = q_c / sum_j q_j
#
# El denominador usa TODAS las causas dentro de:
# anio, pais, sexo, grupo_edad.

composicion_causal <- resultados_bayesiano %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  mutate(
    q_total = sum(q_c, na.rm = TRUE),
    prop_q = if_else(q_total > 0, q_c / q_total, 0)
  ) %>%
  ungroup()


# ---------------------------------------------------------------------------
# 5. Concentración causal
# ---------------------------------------------------------------------------

# H = sum_c prop_q^2
#
# Se calcula con TODAS las causas.

concentracion_causal <- composicion_causal %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  summarise(
    indice_concentracion = sum(prop_q^2, na.rm = TRUE),
    q_total = first(q_total),
    .groups = "drop"
  )


# ---------------------------------------------------------------------------
# 6. Selección de causas por país
# ---------------------------------------------------------------------------

# Regla:
#
# Para cada país se seleccionan 4 causas:
#
# 1. Causas externas de mortalidad, identificada por causa == "XX"
#    o por texto en causa_grupo.
#
# 2. Las 3 causas restantes con mayor q_c promedio dentro del país.
#
# Perinatales se excluye de esta selección porque se grafica aparte.

obtener_causa_externa_pais <- function(datos_pais) {
  
  causa_externa <- datos_pais %>%
    distinct(causa, causa_grupo) %>%
    filter(
      causa == "XX" |
        str_detect(str_to_lower(causa_grupo), "extern")
    ) %>%
    pull(causa_grupo) %>%
    unique()
  
  if (length(causa_externa) > 0) {
    causa_externa[1]
  } else {
    NA_character_
  }
}


obtener_causa_perinatal_pais <- function(datos_pais) {
  
  causa_perinatal <- datos_pais %>%
    distinct(causa_grupo) %>%
    filter(
      str_detect(str_to_lower(causa_grupo), "perinatal")
    ) %>%
    pull(causa_grupo) %>%
    unique()
  
  if (length(causa_perinatal) > 0) {
    causa_perinatal[1]
  } else {
    NA_character_
  }
}


seleccionar_top4_promedio_pais <- function(datos_pais) {
  
  causa_externa <- obtener_causa_externa_pais(datos_pais)
  
  datos_base <- datos_pais %>%
    filter(
      !str_detect(str_to_lower(causa_grupo), "perinatal")
    )
  
  if (!is.na(causa_externa)) {
    
    datos_base <- datos_base %>%
      filter(causa_grupo != causa_externa)
    
    n_resto <- 3
    
  } else {
    
    n_resto <- 4
  }
  
  causas_resto <- datos_base %>%
    group_by(causa_grupo) %>%
    summarise(
      q_promedio = mean(q_c, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(q_promedio)) %>%
    slice_head(n = n_resto) %>%
    pull(causa_grupo)
  
  causas_seleccionadas <- c()
  
  if (!is.na(causa_externa)) {
    causas_seleccionadas <- c(causas_seleccionadas, causa_externa)
  }
  
  causas_seleccionadas <- c(causas_seleccionadas, causas_resto)
  
  unique(causas_seleccionadas)
}


# ---------------------------------------------------------------------------
# 7. Gráficos por país
# ---------------------------------------------------------------------------

paises <- resultados_bayesiano %>%
  distinct(pais, pais_carpeta) %>%
  arrange(pais)


for (i in seq_len(nrow(paises))) {
  
  pais_actual <- paises$pais[i]
  carpeta_pais <- paises$pais_carpeta[i]
  ruta_figuras <- here("figuras", "bayesiano", carpeta_pais)
  
  dir.create(
    ruta_figuras,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  # Limpia gráficos anteriores del análisis bayesiano.
  
  archivos_previos <- list.files(
    ruta_figuras,
    pattern = "^(00|01|02|03|04|05)_.*\\.png$",
    full.names = TRUE
  )
  
  if (length(archivos_previos) > 0) {
    file.remove(archivos_previos)
  }
  
  
  datos_pais <- resultados_bayesiano %>%
    filter(pais == pais_actual)
  
  composicion_pais <- composicion_causal %>%
    filter(pais == pais_actual)
  
  concentracion_pais <- concentracion_causal %>%
    filter(pais == pais_actual)
  
  
  # -------------------------------------------------------------------------
  # 7.1 Seleccionar causas principales del país
  # -------------------------------------------------------------------------
  
  causas_top4_pais <- seleccionar_top4_promedio_pais(datos_pais)
  causa_perinatal_pais <- obtener_causa_perinatal_pais(datos_pais)
  
  orden_causas_top4_wrap <- str_wrap(causas_top4_pais, width = 35)
  
  datos_pais_top4 <- datos_pais %>%
    filter(causa_grupo %in% causas_top4_pais) %>%
    mutate(
      causa_grupo_wrap = factor(
        str_wrap(causa_grupo, width = 35),
        levels = orden_causas_top4_wrap
      )
    )
  
  composicion_pais_top4 <- composicion_pais %>%
    filter(causa_grupo %in% causas_top4_pais) %>%
    mutate(
      causa_grupo_wrap = factor(
        str_wrap(causa_grupo, width = 35),
        levels = orden_causas_top4_wrap
      )
    )
  
  datos_pais_perinatal <- datos_pais %>%
    filter(
      str_detect(str_to_lower(causa_grupo), "perinatal")
    ) %>%
    mutate(
      causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
    )
  
  
  # Causas para gráfico 4:
  # top 4 + perinatal.
  
  causas_grafico_4 <- causas_top4_pais
  
  if (!is.na(causa_perinatal_pais)) {
    causas_grafico_4 <- unique(c(causa_perinatal_pais, causas_grafico_4))
  }
  
  orden_causas_grafico_4_wrap <- str_wrap(causas_grafico_4, width = 35)
  
  composicion_pais_top4_mas_perinatal <- composicion_pais %>%
    filter(causa_grupo %in% causas_grafico_4) %>%
    mutate(
      causa_grupo_wrap = factor(
        str_wrap(causa_grupo, width = 35),
        levels = orden_causas_grafico_4_wrap
      )
    )
  
  # -------------------------------------------------------------------------
  # Gráfico 1: q_c absoluto por edad
  # -------------------------------------------------------------------------
  #
  # Este gráfico junta 2015 y 2018 en una sola figura.
  # Se separa por sexo y por año:
  #
  # filas    = sexo
  # columnas = año
  #
  # Dentro de cada panel se muestran las 4 causas seleccionadas.
  #
  # Escala: 0% a 40%, saltos de 10%.
  
  grafico_01_q_edad <- datos_pais_top4 %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = q_porcentaje,
        group = causa_grupo_wrap,
        color = causa_grupo_wrap
      )
    ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.2) +
    facet_grid(sexo ~ anio) +
    scale_color_npg() +
    scale_y_continuous(
      labels = etiqueta_pct_directa,
      breaks = seq(0, 40, 10),
      minor_breaks = seq(0, 40, 5),
      expand = expansion(mult = c(0, 0.02))
    ) +
    coord_cartesian(ylim = c(0, 40)) +
    labs(
      title = paste0("Probabilidad absoluta de decremento por causa: ", pais_actual),
      subtitle = "q_c x 100. Comparación 2015 y 2018. Causas externas + 3 causas principales por q_c promedio",
      x = "Grupo etario",
      y = "q_c",
      color = "Causa"
    ) +
    tema_bayesiano()
  
  ggsave(
    filename = here("figuras", "bayesiano", carpeta_pais, "01_q_absoluto_top4_2015_2018.png"),
    plot = grafico_01_q_edad,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 2: q_c por causa
  # -------------------------------------------------------------------------
  #
  # q_c x 100.
  # Escala: 0% a 30%, saltos de 10%.
  
  grafico_02_q_causa <- datos_pais_top4 %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = q_porcentaje,
        group = interaction(anio, sexo),
        color = factor(anio),
        linetype = sexo
      )
    ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.2) +
    facet_wrap(~ causa_grupo_wrap) +
    scale_color_npg() +
    scale_y_continuous(
      labels = etiqueta_pct_directa,
      breaks = seq(0, 30, 10),
      minor_breaks = seq(0, 30, 5),
      expand = expansion(mult = c(0, 0.02))
    ) +
    coord_cartesian(ylim = c(0, 30)) +
    labs(
      title = paste0("Variación etaria de q_c por causa: ", pais_actual),
      subtitle = "q_c x 100. Causas externas + 3 causas principales por q_c promedio. Comparación 2015 y 2018",
      x = "Grupo etario",
      y = "q_c",
      color = "Año",
      linetype = "Sexo"
    ) +
    tema_bayesiano()
  
  ggsave(
    filename = here("figuras", "bayesiano", carpeta_pais, "02_q_por_causa_top4.png"),
    plot = grafico_02_q_causa,
    width = 14,
    height = 9,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 3: composición causal condicionada al fallecimiento
  # -------------------------------------------------------------------------
  #
  # prop_q = q_c / sum_j q_j
  #
  # Se agrupan las 4 causas seleccionadas de 2 en 2 para que el gráfico sea
  # legible.
  #
  # Se generan:
  #
  # 03_composicion_condicionada_grupo_1.png
  # 03_composicion_condicionada_grupo_2.png
  #
  # Dentro de cada gráfico se compara 2015 contra 2018.
  #
  # Escala: 0% a 100%, saltos de 25%.
  
  grupos_causas_03 <- split(
    causas_top4_pais,
    ceiling(seq_along(causas_top4_pais) / 2)
  )
  
  for (g in seq_along(grupos_causas_03)) {
    
    causas_grupo_actual <- grupos_causas_03[[g]]
    
    composicion_grupo_actual <- composicion_pais_top4 %>%
      filter(causa_grupo %in% causas_grupo_actual) %>%
      mutate(
        causa_grupo_wrap = factor(
          str_wrap(causa_grupo, width = 35),
          levels = str_wrap(causas_grupo_actual, width = 35)
        )
      )
    
    grafico_03_composicion_goerlich <- composicion_grupo_actual %>%
      ggplot(
        aes(
          x = grupo_edad,
          y = prop_q,
          fill = factor(anio)
        )
      ) +
      geom_col(position = "dodge") +
      facet_grid(sexo ~ causa_grupo_wrap) +
      scale_fill_npg() +
      scale_y_continuous(
        labels = etiqueta_pct_proporcion,
        breaks = seq(0, 1, 0.25),
        minor_breaks = seq(0, 1, 0.125),
        expand = expansion(mult = c(0, 0.02))
      ) +
      coord_cartesian(ylim = c(0, 1)) +
      labs(
        title = paste0("Composición causal condicionada al fallecimiento: ", pais_actual),
        subtitle = "prop_q = q_c / suma_j q_j. Comparación 2015 y 2018. Causas agrupadas de dos en dos",
        x = "Grupo etario",
        y = "Participación condicionada al fallecimiento",
        fill = "Año"
      ) +
      tema_bayesiano()
    
    ggsave(
      filename = here(
        "figuras",
        "bayesiano",
        carpeta_pais,
        paste0("03_composicion_condicionada_grupo_", g, ".png")
      ),
      plot = grafico_03_composicion_goerlich,
      width = 14,
      height = 8,
      dpi = 300
    )
  }
  
  
  # -------------------------------------------------------------------------
  # Gráfico 4: composición causal promedio por edad
  # -------------------------------------------------------------------------
  #
  # Muestra top 4 causas + perinatal.
  #
  # Cada segmento es:
  #
  # prop_q = q_c / sum_j q_j
  #
  # con denominador de todas las causas.
  #
  # Escala: 0% a 100%, saltos de 25%.
  
  grafico_04_composicion_apilada <- composicion_pais_top4_mas_perinatal %>%
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
    scale_fill_npg() +
    scale_y_continuous(
      labels = etiqueta_pct_proporcion,
      breaks = seq(0, 1, 0.25),
      minor_breaks = seq(0, 1, 0.125),
      expand = expansion(mult = c(0, 0.02))
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    labs(
      title = paste0("Composición causal promedio por edad: ", pais_actual),
      subtitle = "Participación relativa dentro de la mortalidad total. Top 4 causas + causa perinatal",
      x = "Grupo etario",
      y = "Participación relativa",
      fill = "Causa"
    ) +
    tema_bayesiano()
  
  ggsave(
    filename = here("figuras", "bayesiano", carpeta_pais, "04_composicion_promedio_top4_mas_perinatal.png"),
    plot = grafico_04_composicion_apilada,
    width = 14,
    height = 8,
    dpi = 300
  )
  
  
  # -------------------------------------------------------------------------
  # Gráfico 5: concentración causal
  # -------------------------------------------------------------------------
  #
  # H = sum_c prop_q^2
  #
  # Se calcula con todas las causas.
  #
  # Escala: 0% a 100%, saltos de 25%.
  
  grafico_05_concentracion <- concentracion_pais %>%
    ggplot(
      aes(
        x = grupo_edad,
        y = indice_concentracion,
        group = sexo,
        color = sexo
      )
    ) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.2) +
    facet_wrap(~ anio) +
    scale_color_npg() +
    scale_y_continuous(
      labels = etiqueta_pct_proporcion,
      breaks = seq(0, 1, 0.25),
      minor_breaks = seq(0, 1, 0.125),
      expand = expansion(mult = c(0, 0.02))
    ) +
    coord_cartesian(ylim = c(0, 1)) +
    labs(
      title = paste0("Concentración causal por grupo etario: ", pais_actual),
      subtitle = "Índice H = suma de participaciones relativas al cuadrado. Calculado con todas las causas",
      x = "Grupo etario",
      y = "Índice de concentración H",
      color = "Sexo"
    ) +
    tema_bayesiano()
  
  ggsave(
    filename = here("figuras", "bayesiano", carpeta_pais, "05_concentracion_causal.png"),
    plot = grafico_05_concentracion,
    width = 14,
    height = 8,
    dpi = 300
  )
}