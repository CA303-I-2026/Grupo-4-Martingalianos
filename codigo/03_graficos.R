library(dplyr)
library(tidyr)
library(ggplot2)
library(ggsci)
library(cowplot)
library(forcats)
library(scales)
library(here)
library(readr)
library(stringr)
library(tibble)

# revisiones de entrada

ruta_eda <- here("datos", "procesados", "eda_base_mortalidad.csv")

if (!file.exists(ruta_eda)) {
  stop("No existe eda_base_mortalidad.csv. Corré primero 02_limpieza_mortalidad.R.")
}

dir.create(here("datos", "procesados"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("figuras"), recursive = TRUE, showWarnings = FALSE)

# estilo común de las figuras

fuente_figuras <- ifelse(.Platform$OS.type == "windows", "Arial", "sans")

graficos_submartingalianos <- function(base_size = 12, base_family = fuente_figuras) {
  cowplot::theme_cowplot(
    font_size = base_size,
    font_family = base_family
  ) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 4, color = "grey10"),
      plot.subtitle = element_text(size = base_size + 1, color = "grey30"),
      plot.caption = element_text(size = base_size - 2, color = "grey40"),
      axis.title = element_text(face = "bold", color = "grey10"),
      axis.text.x = element_text(color = "grey20"),
      axis.text.y = element_text(color = "grey20"),
      strip.background = element_rect(fill = "grey95", color = NA),
      strip.text = element_text(face = "bold", color = "grey10"),
      legend.title = element_text(face = "bold"),
      legend.position = "bottom",
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "white", color = NA),
      panel.grid.major.y = element_line(color = "grey90", linewidth = 0.25),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank()
    )
}

theme_set(graficos_submartingalianos())

# etiquetas y colores

dic_causas <- tribble(
  ~icd10_code, ~causa_nombre,
  1001, "Infecciosas y parasitarias",
  1026, "Neoplasias",
  1048, "Sangre e inmunidad",
  1051, "Endocrinas y metabólicas",
  1055, "Trastornos mentales y del comportamiento",
  1058, "Sistema nervioso",
  1062, "Ojo y anexos",
  1063, "Oído y apófisis mastoides",
  1064, "Sistema circulatorio",
  1072, "Sistema respiratorio",
  1078, "Sistema digestivo",
  1082, "Piel y tejido subcutáneo",
  1083, "Sistema osteomuscular",
  1084, "Sistema genitourinario",
  1087, "Embarazo, parto y puerperio",
  1092, "Condiciones perinatales",
  1093, "Malformaciones congénitas",
  1094, "Síntomas y hallazgos no clasificados",
  1096, "Accidentes de transporte",
  1102, "Agresiones"
)

dic_edades <- tribble(
  ~intervalo_edad, ~edad_grupo, ~edad_orden,
  "Deaths2",  "0",     1,
  "Deaths3",  "1",     2,
  "Deaths4",  "2",     3,
  "Deaths5",  "3",     4,
  "Deaths6",  "4",     5,
  "Deaths7",  "5-9",   6,
  "Deaths8",  "10-14", 7,
  "Deaths9",  "15-19", 8,
  "Deaths10", "20-24", 9,
  "Deaths11", "25-29", 10,
  "Deaths12", "30-34", 11,
  "Deaths13", "35-39", 12,
  "Deaths14", "40-44", 13,
  "Deaths15", "45-49", 14,
  "Deaths16", "50-54", 15,
  "Deaths17", "55-59", 16,
  "Deaths18", "60-64", 17,
  "Deaths19", "65-69", 18,
  "Deaths20", "70-74", 19,
  "Deaths21", "75-79", 20,
  "Deaths22", "80-84", 21,
  "Deaths23", "85-89", 22,
  "Deaths24", "90-94", 23,
  "Deaths25", "95+",   24,
  "Deaths26", "Edad no especificada", 25
)

edades_validas <- dic_edades %>%
  filter(edad_grupo != "Edad no especificada")

# base original en formato tidy

data_base <- read_csv(ruta_eda, show_col_types = FALSE) %>%
  left_join(dic_causas, by = "icd10_code") %>%
  mutate(
    muertes = replace_na(muertes, 0),
    causa_nombre = ifelse(is.na(causa_nombre), "Otra categoría ICD-10", causa_nombre),
    causa_etiqueta = paste0(icd10_code, " · ", causa_nombre),
    edad_grupo = factor(edad_grupo, levels = dic_edades$edad_grupo)
  ) %>%
  filter(edad_grupo != "Edad no especificada") %>%
  group_by(
    Pais, Year, sexo, icd10_code, causa_nombre, causa_etiqueta,
    intervalo_edad, edad_grupo, edad_orden
  ) %>%
  summarise(
    muertes = sum(muertes, na.rm = TRUE),
    .groups = "drop"
  )

# exceso respecto a la mediana de cada estrato

data_eda <- data_base %>%
  group_by(
    Pais, sexo, icd10_code, causa_nombre, causa_etiqueta,
    intervalo_edad, edad_grupo, edad_orden
  ) %>%
  mutate(
    base_mediana = median(muertes, na.rm = TRUE),
    base_media = mean(muertes, na.rm = TRUE),
    exceso_abs = pmax(muertes - base_mediana, 0),
    exceso_rel = ifelse(base_mediana > 0, exceso_abs / base_mediana, NA_real_)
  ) %>%
  ungroup()

write_csv(
  data_eda,
  here("datos", "procesados", "eda_base_excesos_y_original.csv")
)

# causas más frecuentes

tabla_causas <- data_eda %>%
  group_by(icd10_code, causa_nombre, causa_etiqueta) %>%
  summarise(
    muertes_total = sum(muertes, na.rm = TRUE),
    exceso_total = sum(exceso_abs, na.rm = TRUE),
    estratos_con_muertes = sum(muertes > 0, na.rm = TRUE),
    estratos_con_exceso = sum(exceso_abs > 0, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    rank_muertes = min_rank(desc(muertes_total)),
    rank_exceso = min_rank(desc(exceso_total)),
    puntaje = rank_muertes + rank_exceso
  ) %>%
  arrange(puntaje, desc(muertes_total), desc(exceso_total))

n_causas_graficas <- min(10, nrow(tabla_causas))

causas_graficas <- tabla_causas %>%
  slice_head(n = n_causas_graficas) %>%
  pull(causa_etiqueta)

causas_todas <- tabla_causas %>%
  arrange(desc(muertes_total)) %>%
  pull(causa_etiqueta)

data_plot <- data_eda %>%
  filter(causa_etiqueta %in% causas_graficas)

data_all_causas <- data_eda %>%
  filter(causa_etiqueta %in% causas_todas)

paises_graficas <- sort(unique(data_eda$Pais))

cols_causas <- setNames(
  colorRampPalette(pal_npg("nrc")(10))(length(causas_graficas)),
  causas_graficas
)

cols_causas_todas <- setNames(
  colorRampPalette(pal_npg("nrc")(10))(length(causas_todas)),
  causas_todas
)

cols_paises <- setNames(
  colorRampPalette(pal_npg("nrc")(10))(length(paises_graficas)),
  paises_graficas
)

write_csv(
  tabla_causas,
  here("datos", "procesados", "eda_cuadro_1_ranking_causas.csv")
)

# leyendas que se repiten

wrap_lab <- function(x, width = 28) {
  stringr::str_wrap(x, width = width)
}

guia_color_causas <- guides(
  color = guide_legend(
    nrow = 3,
    byrow = TRUE,
    title.position = "top",
    override.aes = list(size = 3, linewidth = 1)
  )
)

guia_fill_causas <- guides(
  fill = guide_legend(
    nrow = 3,
    byrow = TRUE,
    title.position = "top",
    override.aes = list(size = 4)
  )
)

guia_fill_todas_causas <- guides(
  fill = guide_legend(
    ncol = 4,
    byrow = TRUE,
    title.position = "top",
    override.aes = list(size = 4)
  )
)

tema_leyenda_causas <- theme(
  legend.position = "bottom",
  legend.box = "vertical",
  legend.text = element_text(size = 8.2),
  legend.title = element_text(size = 10, face = "bold"),
  legend.key.width = grid::unit(0.55, "cm"),
  legend.key.height = grid::unit(0.45, "cm"),
  legend.spacing.x = grid::unit(0.10, "cm"),
  legend.spacing.y = grid::unit(0.08, "cm"),
  legend.box.spacing = grid::unit(0.18, "cm"),
  plot.margin = margin(10, 16, 22, 10)
)

tema_leyenda_todas_causas <- theme(
  legend.position = "bottom",
  legend.box = "vertical",
  legend.text = element_text(size = 7.1),
  legend.title = element_text(size = 9.5, face = "bold"),
  legend.key.width = grid::unit(0.45, "cm"),
  legend.key.height = grid::unit(0.38, "cm"),
  legend.spacing.x = grid::unit(0.05, "cm"),
  legend.spacing.y = grid::unit(0.04, "cm"),
  legend.box.spacing = grid::unit(0.15, "cm"),
  plot.margin = margin(10, 16, 26, 10)
)

guia_barra_derecha <- guides(
  fill = guide_colorbar(
    title.position = "top",
    title.hjust = 0.5,
    barheight = grid::unit(5.2, "cm"),
    barwidth = grid::unit(0.5, "cm"),
    ticks = TRUE
  )
)

tema_barra_derecha <- theme(
  legend.position = "right",
  legend.direction = "vertical",
  legend.title = element_text(size = 10, face = "bold"),
  legend.text = element_text(size = 8.5),
  legend.key.height = grid::unit(0.5, "cm"),
  legend.margin = margin(0, 0, 0, 6),
  plot.margin = margin(10, 10, 14, 10)
)

# resúmenes de las muertes observadas

original_pais_anio <- data_eda %>%
  group_by(Pais, Year) %>%
  summarise(
    muertes_total = sum(muertes, na.rm = TRUE),
    .groups = "drop"
  )

original_edad_causa <- data_plot %>%
  group_by(causa_etiqueta, edad_orden) %>%
  summarise(
    muertes_total = sum(muertes, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  complete(
    causa_etiqueta = causas_graficas,
    edad_orden = edades_validas$edad_orden,
    fill = list(muertes_total = 0)
  ) %>%
  left_join(
    edades_validas %>% select(edad_orden, edad_grupo),
    by = "edad_orden"
  ) %>%
  mutate(
    edad_grupo = factor(edad_grupo, levels = dic_edades$edad_grupo)
  )

original_composicion_edad_todas <- data_all_causas %>%
  group_by(causa_etiqueta, edad_orden) %>%
  summarise(
    muertes_total = sum(muertes, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  complete(
    causa_etiqueta = causas_todas,
    edad_orden = edades_validas$edad_orden,
    fill = list(muertes_total = 0)
  ) %>%
  left_join(
    edades_validas %>% select(edad_orden, edad_grupo),
    by = "edad_orden"
  ) %>%
  mutate(
    edad_grupo = factor(edad_grupo, levels = dic_edades$edad_grupo)
  ) %>%
  group_by(edad_orden, edad_grupo) %>%
  mutate(
    total_edad = sum(muertes_total, na.rm = TRUE),
    peso_causa_edad = ifelse(total_edad > 0, muertes_total / total_edad, 0)
  ) %>%
  ungroup()

original_top_estratos <- data_plot %>%
  group_by(Pais, Year, sexo, edad_grupo, edad_orden, causa_etiqueta) %>%
  summarise(
    muertes_total = sum(muertes, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(muertes_total > 0) %>%
  arrange(desc(muertes_total)) %>%
  slice_head(n = 25)

# resúmenes de los excesos

exceso_edad_causa <- data_plot %>%
  group_by(causa_etiqueta, edad_orden) %>%
  summarise(
    exceso_abs = sum(exceso_abs, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  complete(
    causa_etiqueta = causas_graficas,
    edad_orden = edades_validas$edad_orden,
    fill = list(exceso_abs = 0)
  ) %>%
  left_join(
    edades_validas %>% select(edad_orden, edad_grupo),
    by = "edad_orden"
  ) %>%
  mutate(
    edad_grupo = factor(edad_grupo, levels = dic_edades$edad_grupo)
  )

exceso_top_estratos <- data_plot %>%
  group_by(Pais, Year, sexo, edad_grupo, edad_orden, causa_etiqueta) %>%
  summarise(
    muertes = sum(muertes, na.rm = TRUE),
    base_mediana = sum(base_mediana, na.rm = TRUE),
    exceso_abs = sum(exceso_abs, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(exceso_abs > 0) %>%
  arrange(desc(exceso_abs)) %>%
  slice_head(n = 25)

exceso_burbujas <- data_plot %>%
  group_by(Pais, Year, sexo, edad_grupo, edad_orden, causa_etiqueta) %>%
  summarise(
    exceso_abs = sum(exceso_abs, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(exceso_abs > 0) %>%
  arrange(desc(exceso_abs)) %>%
  slice_head(n = 80)

# guardamos los cuadros que usa la bitácora

write_csv(original_pais_anio, here("datos", "procesados", "eda_original_1_pais_anio.csv"))
write_csv(original_edad_causa, here("datos", "procesados", "eda_original_2_edad_causa.csv"))
write_csv(original_composicion_edad_todas, here("datos", "procesados", "eda_original_3_composicion_edad_todas.csv"))
write_csv(original_top_estratos, here("datos", "procesados", "eda_original_4_top_estratos.csv"))

write_csv(exceso_edad_causa, here("datos", "procesados", "eda_exceso_1_edad_causa.csv"))
write_csv(exceso_top_estratos, here("datos", "procesados", "eda_exceso_2_top_estratos.csv"))
write_csv(exceso_burbujas, here("datos", "procesados", "eda_exceso_3_burbujas.csv"))


# gráficos de las muertes observadas

# muertes por país y año
g1_original_pais_anio <- original_pais_anio %>%
  mutate(Pais = factor(Pais, levels = paises_graficas)) %>%
  ggplot(aes(x = factor(Year), y = Pais, fill = muertes_total)) +
  geom_tile(color = "white", linewidth = 0.45) +
  geom_text(aes(label = comma(round(muertes_total, 0))), size = 3.4) +
  scale_fill_gradient(
    low = "white",
    high = pal_npg("nrc")(10)[1],
    labels = label_comma()
  ) +
  guia_barra_derecha +
  labs(
    title = "Muertes registradas por país y año",
    subtitle = "Volumen total de defunciones en el periodo 2015-2018",
    x = "Año",
    y = "País",
    fill = "Muertes",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_barra_derecha

# mapa de calor por edad y causa
g2_original_heatmap_edad_causa <- original_edad_causa %>%
  mutate(causa_etiqueta = fct_reorder(causa_etiqueta, muertes_total, .fun = sum)) %>%
  ggplot(aes(x = edad_grupo, y = causa_etiqueta, fill = muertes_total)) +
  geom_tile(color = "white", linewidth = 0.25) +
  scale_fill_gradient(
    low = "white",
    high = pal_npg("nrc")(10)[1],
    labels = label_comma()
  ) +
  guia_barra_derecha +
  labs(
    title = "Dónde se concentran las muertes por edad y causa",
    subtitle = "Las celdas más intensas muestran mayor número de defunciones acumuladas",
    x = "Grupo de edad",
    y = "Categoría ICD-10",
    fill = "Muertes",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_barra_derecha +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# perfil por edad
g3_original_perfil_edad <- original_edad_causa %>%
  ggplot(aes(x = edad_orden, y = muertes_total, color = causa_etiqueta, group = causa_etiqueta)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.8) +
  scale_color_manual(
    values = cols_causas,
    labels = function(x) wrap_lab(x, 26)
  ) +
  guia_color_causas +
  scale_x_continuous(
    breaks = edades_validas$edad_orden,
    labels = edades_validas$edad_grupo
  ) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Perfil de muertes según grupo de edad",
    subtitle = "Forma etaria de las categorías ICD-10 seleccionadas",
    x = "Grupo de edad",
    y = "Muertes acumuladas",
    color = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_causas +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# composición por edad con todas las causas
g4_original_composicion_edad <- original_composicion_edad_todas %>%
  mutate(causa_etiqueta = factor(causa_etiqueta, levels = causas_todas)) %>%
  ggplot(aes(x = edad_orden, y = peso_causa_edad, fill = causa_etiqueta)) +
  geom_area(alpha = 0.96, linewidth = 0.08, color = "white") +
  scale_fill_manual(
    values = cols_causas_todas,
    labels = function(x) wrap_lab(x, 24)
  ) +
  guia_fill_todas_causas +
  scale_x_continuous(
    breaks = edades_validas$edad_orden,
    labels = edades_validas$edad_grupo
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Composición de las muertes a través de la edad",
    subtitle = "Todas las categorías ICD-10 disponibles en la base",
    x = "Grupo de edad",
    y = "Participación dentro de las muertes de cada edad",
    fill = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_todas_causas +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# estratos con más muertes
g5_original_top_estratos <- original_top_estratos %>%
  mutate(
    estrato = paste(Pais, Year, sexo, edad_grupo, causa_etiqueta, sep = " · "),
    estrato = str_wrap(estrato, width = 70),
    estrato = fct_reorder(estrato, muertes_total)
  ) %>%
  ggplot(aes(x = muertes_total, y = estrato)) +
  geom_segment(
    aes(x = 0, xend = muertes_total, y = estrato, yend = estrato),
    color = "grey70",
    linewidth = 0.8
  ) +
  geom_point(aes(color = causa_etiqueta), size = 3.2) +
  scale_color_manual(
    values = cols_causas,
    labels = function(x) wrap_lab(x, 26)
  ) +
  guia_color_causas +
  scale_x_continuous(labels = label_comma()) +
  labs(
    title = "Estratos con mayor número de muertes registradas",
    subtitle = "Cada punto combina país, año, sexo, edad y categoría de causa",
    x = "Muertes registradas",
    y = NULL,
    color = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_causas

# gráficos de los excesos

# mapa de calor por edad y causa
g6_exceso_heatmap_edad_causa <- exceso_edad_causa %>%
  mutate(causa_etiqueta = fct_reorder(causa_etiqueta, exceso_abs, .fun = sum)) %>%
  ggplot(aes(x = edad_grupo, y = causa_etiqueta, fill = exceso_abs)) +
  geom_tile(color = "white", linewidth = 0.25) +
  scale_fill_gradient(
    low = "white",
    high = pal_npg("nrc")(10)[1],
    labels = label_comma()
  ) +
  guia_barra_derecha +
  labs(
    title = "Dónde se concentran los excesos por edad y causa",
    subtitle = "Las celdas más intensas muestran estratos edad-causa con mayor exceso absoluto acumulado",
    x = "Grupo de edad",
    y = "Categoría ICD-10",
    fill = "Exceso",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_barra_derecha +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# perfil por edad
g7_exceso_perfil_edad <- exceso_edad_causa %>%
  ggplot(aes(x = edad_orden, y = exceso_abs, color = causa_etiqueta, group = causa_etiqueta)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.8) +
  scale_color_manual(
    values = cols_causas,
    labels = function(x) wrap_lab(x, 26)
  ) +
  guia_color_causas +
  scale_x_continuous(
    breaks = edades_validas$edad_orden,
    labels = edades_validas$edad_grupo
  ) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Perfil del exceso según grupo de edad",
    subtitle = "Permite ver si el exceso se concentra en edades jóvenes, adultas o avanzadas",
    x = "Grupo de edad",
    y = "Exceso absoluto acumulado",
    color = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_causas +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# estratos con mayor exceso
g8_exceso_top_estratos <- exceso_top_estratos %>%
  mutate(
    estrato = paste(Pais, Year, sexo, edad_grupo, causa_etiqueta, sep = " · "),
    estrato = str_wrap(estrato, width = 70),
    estrato = fct_reorder(estrato, exceso_abs)
  ) %>%
  ggplot(aes(x = exceso_abs, y = estrato)) +
  geom_segment(
    aes(x = 0, xend = exceso_abs, y = estrato, yend = estrato),
    color = "grey70",
    linewidth = 0.8
  ) +
  geom_point(aes(color = causa_etiqueta), size = 3.2) +
  scale_color_manual(
    values = cols_causas,
    labels = function(x) wrap_lab(x, 26)
  ) +
  guia_color_causas +
  scale_x_continuous(labels = label_comma()) +
  labs(
    title = "Estratos con mayor exceso descriptivo",
    subtitle = "Cada punto combina país, año, sexo, edad y categoría de causa",
    x = "Exceso absoluto de muertes",
    y = NULL,
    color = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_causas

# burbujas para los estratos más atípicos
g9_exceso_burbujas <- exceso_burbujas %>%
  mutate(
    pais_anio = paste(Pais, Year, sep = " · "),
    pais_anio = fct_reorder(pais_anio, exceso_abs, .fun = max),
    causa_etiqueta = factor(causa_etiqueta, levels = causas_graficas)
  ) %>%
  ggplot(aes(x = edad_orden, y = pais_anio)) +
  geom_point(
    aes(size = exceso_abs, fill = causa_etiqueta),
    shape = 21,
    color = "grey20",
    alpha = 0.85
  ) +
  facet_wrap(~ sexo) +
  scale_fill_manual(
    values = cols_causas,
    labels = function(x) wrap_lab(x, 26),
    na.value = "grey70"
  ) +
  guia_fill_causas +
  scale_size_continuous(range = c(2, 11), labels = label_comma()) +
  scale_x_continuous(
    breaks = edades_validas$edad_orden[edades_validas$edad_orden %% 3 == 0],
    labels = edades_validas$edad_grupo[edades_validas$edad_orden %% 3 == 0]
  ) +
  labs(
    title = "Estratos críticos de exceso",
    subtitle = "Cada burbuja combina país, año, sexo, edad y causa",
    x = "Grupo de edad",
    y = "País y año",
    size = "Exceso",
    fill = "Causa",
    caption = "Fuente: WHO Mortality Database. Elaboración propia."
  ) +
  tema_leyenda_causas +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# guardamos solo las nueve figuras que aparecen en la bitácora 2

cowplot::save_plot(
  here("figuras", "04_g1_original_pais_anio.png"),
  g1_original_pais_anio,
  base_width = 12.5,
  base_height = 7,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g2_original_heatmap_edad_causa.png"),
  g2_original_heatmap_edad_causa,
  base_width = 14,
  base_height = 8.5,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g3_original_perfil_edad.png"),
  g3_original_perfil_edad,
  base_width = 16,
  base_height = 9.2,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g4_original_composicion_edad.png"),
  g4_original_composicion_edad,
  base_width = 18,
  base_height = 11.2,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g5_original_top_estratos.png"),
  g5_original_top_estratos,
  base_width = 15.5,
  base_height = 10.2,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g6_exceso_heatmap_edad_causa.png"),
  g6_exceso_heatmap_edad_causa,
  base_width = 14,
  base_height = 8.5,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g7_exceso_perfil_edad.png"),
  g7_exceso_perfil_edad,
  base_width = 16,
  base_height = 9.2,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g8_exceso_top_estratos.png"),
  g8_exceso_top_estratos,
  base_width = 15.5,
  base_height = 10.2,
  dpi = 320,
  bg = "white"
)

cowplot::save_plot(
  here("figuras", "04_g9_exceso_burbujas.png"),
  g9_exceso_burbujas,
  base_width = 16,
  base_height = 10,
  dpi = 320,
  bg = "white"
)

