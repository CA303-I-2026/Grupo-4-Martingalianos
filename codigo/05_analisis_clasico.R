# 05_analisis_clasico.R

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
# 1. Cargar resultados del enfoque clásico
# ---------------------------------------------------------------------------

resultados_clasico <- read_csv(
  here("datos", "procesados", "resultados_enfoque_clasico.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)

# ---------------------------------------------------------------------------
# Gráfico adicional: composición causal completa para Nicaragua
# ---------------------------------------------------------------------------
#
# Este gráfico muestra la composición causal promedio por grupo etario para
# Nicaragua, incluyendo todas las causas disponibles.
#
# A diferencia del gráfico 04 original, aquí no se seleccionan únicamente
# las top 4 causas. Se usan todas las causas, por lo que cada barra representa
# el 100% de la composición causal.
#
# Cantidad graficada:
#
#   pi_x^(c) = q_x^(c) / sum_j q_x^(j)
#
# Se promedia por grupo etario y causa sobre las combinaciones disponibles
# de año y sexo que estén en resultados_clasico.
#
# Nota: si resultados_clasico ya fue filtrado a 2015 y 2018, este gráfico
# promedia solamente esos años.
# ---------------------------------------------------------------------------


# 1. Construir composición causal completa ----------------------------------

composicion_nicaragua_completa <- resultados_clasico %>%
  filter(pais == "Nicaragua") %>%
  group_by(anio, sexo, grupo_edad) %>%
  mutate(
    q_total = sum(q_c, na.rm = TRUE),
    prop_q = if_else(
      q_total > 0,
      q_c / q_total,
      0
    )
  ) %>%
  ungroup()


# 2. Promediar composición por edad y causa ---------------------------------
#
# Esto genera una lectura promedio de la participación causal por grupo etario,
# agregando las combinaciones de sexo y año presentes en la base.

comp_causal_prima_nic <- composicion_nicaragua_completa %>%
  group_by(grupo_edad, causa, causa_grupo) %>%
  summarise(
    prop_q_promedio = mean(prop_q, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    grupo_edad = factor(grupo_edad, levels = orden_edades),
    causa_grupo_wrap = str_wrap(causa_grupo, width = 35)
  )


# 3. Verificación: las barras deben sumar aproximadamente 1 ------------------

revision_suma_nic <- comp_causal_prima_nic %>%
  group_by(grupo_edad) %>%
  summarise(
    suma_prop = sum(prop_q_promedio, na.rm = TRUE),
    .groups = "drop"
  )

print(revision_suma_nic)


# 4. Crear gráfico -----------------------------------------------------------

grafico_comp_causal_prima_nic <- ggplot(
  comp_causal_prima_nic,
  aes(
    x = grupo_edad,
    y = prop_q_promedio,
    fill = causa_grupo_wrap
  )
) +
  geom_col(
    position = "fill",
    width = 0.85
  ) +
  scale_y_continuous(
    labels = etiqueta_pct_proporcion,
    limits = c(0, 1),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Composición causal completa por edad: Nicaragua",
    subtitle = "Todas las causas incluidas. Cada barra representa el 100% de la composición causal.",
    x = "Grupo etario",
    y = "Participación relativa",
    fill = "Causa"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(size = 10),
    panel.grid.major.x = element_blank()
  ) +
  guides(
    fill = guide_legend(ncol = 2)
  )


# 5. Guardar gráfico en carpeta de Nicaragua --------------------------------

ruta_nicaragua <- here("figuras", "clasico", "nicaragua")

dir.create(
  ruta_nicaragua,
  recursive = TRUE,
  showWarnings = FALSE
)

ggsave(
  filename = here(
    "figuras",
    "clasico",
    "nicaragua",
    "comp_causal_prima_nic.png"
  ),
  plot = grafico_comp_causal_prima_nic,
  width = 14,
  height = 9,
  dpi = 300,
  bg = "white"
)


# 6. Mostrar gráfico ---------------------------------------------------------

grafico_comp_causal_prima_nic


# Solo se contrastan 2015 y 2018

anios_comparacion <- c(2015, 2018)

resultados_clasico <- resultados_clasico %>%
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


tema_clasico <- function() {
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

orden_edades <- resultados_clasico %>%
  distinct(grupo_edad) %>%
  mutate(
    edad_inicio = parse_number(grupo_edad)
  ) %>%
  arrange(edad_inicio) %>%
  pull(grupo_edad)


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
    q_porcentaje = q_c * 100
  )


# ---------------------------------------------------------------------------
# 4. Composición causal condicionada al fallecimiento
# ---------------------------------------------------------------------------

# prop_q = q_c / sum_j q_j
#
# El denominador usa TODAS las causas dentro de:
# anio, pais, sexo, grupo_edad.

composicion_causal <- resultados_clasico %>%
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
    mu_total = first(mu_total),
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
      muertes_totales = sum(muertes, na.rm = TRUE),
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

paises <- resultados_clasico %>%
  distinct(pais, pais_carpeta) %>%
  arrange(pais)


for (i in seq_len(nrow(paises))) {
  
  pais_actual <- paises$pais[i]
  carpeta_pais <- paises$pais_carpeta[i]
  ruta_figuras <- here("figuras", "clasico", carpeta_pais)
  
  # Limpia gráficos anteriores del análisis clásico.
  
  archivos_previos <- list.files(
    ruta_figuras,
    pattern = "^(00|01|02|03|04|05)_.*\\.png$",
    full.names = TRUE
  )
  
  if (length(archivos_previos) > 0) {
    file.remove(archivos_previos)
  }
  
  
  datos_pais <- resultados_clasico %>%
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
  # Gráfico 0: q_c perinatal por edad
  # -------------------------------------------------------------------------
  
  if (nrow(datos_pais_perinatal) > 0) {
    
    max_perinatal <- max(datos_pais_perinatal$q_porcentaje, na.rm = TRUE)
    
    limite_perinatal <- if_else(
      is.finite(max_perinatal) & max_perinatal > 0,
      max_perinatal * 1.15,
      0.01
    )
    
    grafico_00_perinatal <- datos_pais_perinatal %>%
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
      geom_point(size = 1.3) +
      scale_color_npg() +
      scale_y_continuous(
        labels = etiqueta_pct_directa,
        breaks = pretty(c(0, limite_perinatal), n = 5),
        expand = expansion(mult = c(0, 0.03))
      ) +
      coord_cartesian(ylim = c(0, limite_perinatal)) +
      labs(
        title = paste0("Probabilidad de decremento por afecciones perinatales: ", pais_actual),
        subtitle = "q_c x 100. Causa graficada por separado por su perfil etario temprano",
        x = "Grupo etario",
        y = "q_c",
        color = "Año",
        linetype = "Sexo"
      ) +
      tema_clasico()
    
    ggsave(
      filename = here("figuras", "clasico", carpeta_pais, "00_q_perinatal_por_edad.png"),
      plot = grafico_00_perinatal,
      width = 13,
      height = 7,
      dpi = 300
    )
  }
  
  
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
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "01_q_absoluto_top4_2015_2018.png"),
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
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "02_q_por_causa_top4.png"),
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
      tema_clasico()
    
    ggsave(
      filename = here(
        "figuras",
        "clasico",
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
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "04_composicion_promedio_top4_mas_perinatal.png"),
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
    tema_clasico()
  
  ggsave(
    filename = here("figuras", "clasico", carpeta_pais, "05_concentracion_causal.png"),
    plot = grafico_05_concentracion,
    width = 14,
    height = 8,
    dpi = 300
  )
}

# ---------------------------------------------------------------------------
# 8. Gráfico 6: radar de q_c clásico por país para Tumores
# ---------------------------------------------------------------------------
#
# Funcion para radar gráficos compara países alrededor de un radar.
#
# Cantidad graficada:
#
#   q_c x 100
#
# para la causa II = Tumores.
#
# Interpretación:
#   Probabilidad anual local de decremento por tumores para un grupo etario,
#   sexo y año dados.
#
#
# ---------------------------------------------------------------------------


crear_radar_clasico <- function(
    datos,
    causa_radar,
    nombre_causa_radar,
    grupo_edad_radar,
    sexo_radar,
    anios_radar = c(2015, 2018),
    orden_paises_radar = c(
      "Belice",
      "Guatemala",
      "El Salvador",
      "Nicaragua",
      "Costa Rica",
      "Panama"
    ),
    guardar_csv = FALSE,
    ruta_salida = here("figuras", "clasico", "radar")
) {
  
  # 1. Filtrar la base para la causa, edad, sexo y años seleccionados --------
  
  radar_base <- datos %>%
    filter(
      causa == causa_radar,
      grupo_edad == grupo_edad_radar,
      sexo == sexo_radar,
      anio %in% anios_radar
    ) %>%
    mutate(
      # Se estandariza el nombre de Panamá para evitar problemas con tilde
      pais = case_when(
        pais == "Panamá" ~ "Panama",
        TRUE ~ pais
      ),
      
      # Se fija el orden de los países alrededor del radar
      pais = factor(pais, levels = orden_paises_radar),
      
      # Se trata el año como categoría para que cada año sea una línea
      anio = factor(anio),
      
      # Se expresa q_c como porcentaje
      q_porcentaje = q_c * 100
    ) %>%
    arrange(anio, pais)
  
  
  # 2. Validaciones básicas --------------------------------------------------
  
  if (nrow(radar_base) == 0) {
    stop("No hay datos para la causa, grupo etario, sexo y años seleccionados.")
  }
  
  if (any(is.na(radar_base$pais))) {
    stop("Hay países en los datos que no están incluidos en orden_paises_radar.")
  }
  
  
  # 3. Definir la escala radial ---------------------------------------------
  
  max_radar <- max(radar_base$q_porcentaje, na.rm = TRUE)
  
  radio_max <- ifelse(
    is.finite(max_radar) && max_radar > 0,
    max_radar * 1.20,
    0.01
  )
  
  breaks_radio <- pretty(c(0, radio_max), n = 4)
  breaks_radio <- breaks_radio[breaks_radio >= 0]
  radio_max <- max(breaks_radio)
  
  
  # 4. Construir coordenadas para ubicar países en el círculo ----------------
  
  n_paises <- length(orden_paises_radar)
  
  coords_paises <- tibble(
    pais = factor(orden_paises_radar, levels = orden_paises_radar),
    indice = seq_len(n_paises),
    angulo = pi / 2 - 2 * pi * (indice - 1) / n_paises
  ) %>%
    mutate(
      # Coordenadas de los ejes radiales
      x_eje = radio_max * cos(angulo),
      y_eje = radio_max * sin(angulo),
      
      # Coordenadas de las etiquetas de países
      x_label = 1.12 * radio_max * cos(angulo),
      y_label = 1.12 * radio_max * sin(angulo)
    )
  
  
  # 5. Convertir q_porcentaje a coordenadas cartesianas ----------------------
  
  radar_xy <- radar_base %>%
    left_join(
      coords_paises,
      by = "pais"
    ) %>%
    mutate(
      x = q_porcentaje * cos(angulo),
      y = q_porcentaje * sin(angulo)
    ) %>%
    arrange(anio, indice)
  
  
  # 6. Cerrar los polígonos --------------------------------------------------
  #
  # Para que cada línea del radar cierre, se repite el primer país al final
  # de cada año.
  
  radar_xy_cerrado <- radar_xy %>%
    group_by(anio) %>%
    group_modify(~ bind_rows(.x, slice(.x, 1))) %>%
    ungroup()
  
  
  # 7. Crear círculos guía del radar -----------------------------------------
  
  grid_circulos <- tidyr::expand_grid(
    radio = breaks_radio[breaks_radio > 0],
    theta = seq(0, 2 * pi, length.out = 361)
  ) %>%
    mutate(
      x = radio * cos(theta),
      y = radio * sin(theta)
    )
  
  
  # 8. Crear ejes radiales ---------------------------------------------------
  
  ejes_radar <- coords_paises %>%
    transmute(
      pais,
      x = 0,
      y = 0,
      xend = x_eje,
      yend = y_eje
    )
  
  
  # 9. Etiquetas de los radios -----------------------------------------------
  
  etiquetas_radio <- tibble(
    radio = breaks_radio[breaks_radio > 0]
  ) %>%
    mutate(
      x = -radio,
      y = 0,
      etiqueta = etiqueta_pct_directa(radio)
    )
  
  
  # 10. Construir el gráfico -------------------------------------------------
  
  grafico <- ggplot() +
    
    # Círculos de referencia
    geom_path(
      data = grid_circulos,
      aes(x = x, y = y, group = radio),
      color = "grey80",
      linewidth = 0.5
    ) +
    
    # Ejes hacia cada país
    geom_segment(
      data = ejes_radar,
      aes(x = x, y = y, xend = xend, yend = yend),
      color = "grey75",
      linetype = "dotted",
      linewidth = 0.6
    ) +
    
    # Etiquetas de porcentaje en los radios
    geom_text(
      data = etiquetas_radio,
      aes(x = x, y = y, label = etiqueta),
      color = "grey35",
      size = 3,
      hjust = 1.1
    ) +
    
    # Líneas del radar por año
    geom_path(
      data = radar_xy_cerrado,
      aes(
        x = x,
        y = y,
        group = anio,
        color = anio,
        linetype = anio
      ),
      linewidth = 1
    ) +
    
    # Puntos observados por país y año
    geom_point(
      data = radar_xy,
      aes(
        x = x,
        y = y,
        color = anio
      ),
      size = 2.4
    ) +
    
    # Etiquetas de países alrededor del radar
    geom_text(
      data = coords_paises,
      aes(
        x = x_label,
        y = y_label,
        label = pais
      ),
      color = "grey20",
      fontface = "bold",
      size = 3.5
    ) +
    
    scale_color_npg() +
    coord_equal(clip = "off") +
    
    labs(
      title = paste0(
        "Probabilidad local de decremento por ",
        str_to_lower(nombre_causa_radar),
        " por país"
      ),
     subtitle = bquote(
  100 %*% q[c] ~ ". Grupo etario " ~ .(grupo_edad_radar) ~
    ", sexo: " ~ .(sexo_radar) ~
    ". Comparación " ~ .(paste(anios_radar, collapse = " y ")) ~ "."
      ),
      color = "Año",
      linetype = "Año"
    ) +
    
    theme_void(base_size = 12) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "white", color = NA),
      legend.box.background = element_rect(fill = "white", color = NA),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold", color = "black"),
      plot.subtitle = element_text(color = "black"),
      plot.margin = margin(20, 40, 20, 40)
    )
  
  
  # 11. Crear carpeta de salida ----------------------------------------------
  
  dir.create(
    ruta_salida,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  
  # 12. Nombre automático del archivo ----------------------------------------
  
  nombre_archivo <- paste0(
    "06_radar_",
    str_to_lower(str_replace_all(nombre_causa_radar, " ", "_")),
    "_",
    grupo_edad_radar,
    "_",
    str_to_lower(sexo_radar),
    ".png"
  )
  
  
  # 13. Guardar figura -------------------------------------------------------
  
  ggsave(
    filename = file.path(ruta_salida, nombre_archivo),
    plot = grafico,
    width = 10,
    height = 8,
    dpi = 300,
    bg = "white"
  )
  
  
  # 14. Guardar tabla usada en el radar, si se solicita ----------------------
  #
  # No es necesario para generar el gráfico.
  # Solo sirve para auditoría o revisión posterior.
  
  if (guardar_csv) {
    write_csv(
      radar_base,
      file.path(
        ruta_salida,
        str_replace(nombre_archivo, "\\.png$", "_datos.csv")
      )
    )
  }
  
  
  # 15. Devolver el gráfico --------------------------------------------------
  
  return(grafico)
}


grafico_07_radar_causaext_20_24_mujer <- crear_radar_clasico(
  datos = resultados_clasico,
  causa_radar = "XX",
  nombre_causa_radar = "Causas Externas",
  grupo_edad_radar = "20-24",
  sexo_radar = "Mujer",
  anios_radar = c(2015, 2018),
  guardar_csv = FALSE
)


grafico_07_radar_causaext_20_24_hombre <- crear_radar_clasico(
  datos = resultados_clasico,
  causa_radar = "IX",
  nombre_causa_radar = "Sistema circulatorio",
  grupo_edad_radar = "65-69",
  sexo_radar = "Hombre",
  anios_radar = c(2015, 2018),
  guardar_csv = FALSE
)
