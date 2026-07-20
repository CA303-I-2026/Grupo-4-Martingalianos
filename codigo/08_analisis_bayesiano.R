library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(stringr)
library(scales)
library(ggsci)

options(scipen = 999)


# cargamos los resultados bayesianos

resultados_bayesiano <- read_csv(
  here("datos", "procesados", "resultados_enfoque_bayesiano.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)


# para las figuras comparamos el inicio y el cierre del periodo

anios_comparacion <- c(2015, 2018)

resultados_bayesiano <- resultados_bayesiano %>%
  filter(anio %in% anios_comparacion)


# funciones cortas para porcentajes y estilo

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


# orden y etiquetas que se usan en todas las figuras

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


# composición causal dentro de cada celda: prop_q = q_c / sum_j q_j
# el denominador siempre incluye todas las causas

composicion_causal <- resultados_bayesiano %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  mutate(
    q_total = sum(q_c, na.rm = TRUE),
    prop_q = if_else(q_total > 0, q_c / q_total, 0)
  ) %>%
  ungroup()


# concentración causal H = sum_c prop_q^2, también con todas las causas

concentracion_causal <- composicion_causal %>%
  group_by(anio, pais, pais_carpeta, sexo, grupo_edad) %>%
  summarise(
    indice_concentracion = sum(prop_q^2, na.rm = TRUE),
    q_total = first(q_total),
    .groups = "drop"
  )


# en cada país dejamos causas externas y las otras tres con mayor q promedio
# la causa perinatal queda fuera porque no aparece en estas figuras

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


# figuras que sí quedaron citadas en la bitácora 3

figuras_bitacora <- list(
  "costa rica" = c(
    "01_q_absoluto_top4_2015_2018.png",
    "03_composicion_condicionada_grupo_1.png",
    "05_concentracion_causal.png"
  ),
  "guatemala" = c(
    "01_q_absoluto_top4_2015_2018.png",
    "03_composicion_condicionada_grupo_2.png"
  ),
  "nicaragua" = c(
    "01_q_absoluto_top4_2015_2018.png",
    "02_q_por_causa_top4.png"
  )
)

guardar_figura <- function(grafico, carpeta, archivo, width, height) {
  if (!archivo %in% figuras_bitacora[[carpeta]]) {
    return(invisible(FALSE))
  }

  ggsave(
    filename = here("figuras", "Bayesiano", carpeta, archivo),
    plot = grafico,
    width = width,
    height = height,
    dpi = 300
  )
}

# solo procesamos los países que aparecen en esas figuras

paises <- resultados_bayesiano %>%
  distinct(pais, pais_carpeta) %>%
  filter(pais_carpeta %in% names(figuras_bitacora)) %>%
  arrange(pais)


for (i in seq_len(nrow(paises))) {
  
  pais_actual <- paises$pais[i]
  carpeta_pais <- paises$pais_carpeta[i]
  ruta_figuras <- here("figuras", "Bayesiano", carpeta_pais)
  
  dir.create(
    ruta_figuras,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  # quitamos versiones anteriores para no mezclar resultados
  
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
  
  
# causas principales del país
  
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
  
  
# para la composición usamos las cuatro principales más la perinatal
  
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
  
# q absoluto por edad; filas por sexo y columnas por año
  
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
  
  guardar_figura(
    grafico_01_q_edad, carpeta_pais, "01_q_absoluto_top4_2015_2018.png", 14, 8
  )
  
  
# q por causa, expresada en porcentaje
  
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
  
  guardar_figura(
    grafico_02_q_causa, carpeta_pais, "02_q_por_causa_top4.png", 14, 9
  )
  
  
# composición condicionada; separamos las causas de dos en dos para leerla bien
  
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
    
    guardar_figura(
      grafico_03_composicion_goerlich,
      carpeta_pais,
      paste0("03_composicion_condicionada_grupo_", g, ".png"),
      14,
      8
    )
  }
  
  
# composición promedio por edad para las causas elegidas
  
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
  
  guardar_figura(
    grafico_04_composicion_apilada,
    carpeta_pais,
    "04_composicion_promedio_top4_mas_perinatal.png",
    14,
    8
  )
  
  
# concentración causal por edad
  
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
  
  guardar_figura(
    grafico_05_concentracion, carpeta_pais, "05_concentracion_causal.png", 14, 8
  )
}
