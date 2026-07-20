# arma la base de mortalidad y la une con la exposición ya limpia

library(data.table)
library(tidyverse)
library(here)

# rutas de entrada y salida

rutas_mortalidad <- c(
  here("datos", "originales"),
  here("proyecto_final", "datos_final", "originales")
)

rutas_catalogo_eda <- c(
  here("datos", "catalogo_causas_eda.csv"),
  here("proyecto_final", "datos_final", "catalogo_causas_eda.csv")
)

archivos_requeridos <- paste0("Morticd10_part", 1:6)
directorio_completo <- vapply(
  rutas_mortalidad,
  function(ruta) all(file.exists(file.path(ruta, archivos_requeridos))),
  logical(1)
)

ruta_mortalidad <- rutas_mortalidad[directorio_completo][1]
ruta_catalogo_eda <- rutas_catalogo_eda[file.exists(rutas_catalogo_eda)][1]
ruta_salida <- here("datos", "procesados")

dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)

# juntamos las seis partes de mortalidad de la OMS

if (is.na(ruta_mortalidad)) {
  stop(
    "No se encontraron los seis archivos Morticd10_part1 a Morticd10_part6. ",
    "Se revisaron estas carpetas:\n",
    paste(rutas_mortalidad, collapse = "\n")
  )
}

if (is.na(ruta_catalogo_eda)) {
  stop("No se encontró catalogo_causas_eda.csv en datos/ ni en proyecto_final/datos_final/.")
}

archivos_mortalidad <- file.path(ruta_mortalidad, archivos_requeridos)

archivos_faltantes <- archivos_mortalidad[!file.exists(archivos_mortalidad)]

if (length(archivos_faltantes) > 0) {
  stop(
    "No se encontraron archivos crudos de mortalidad:\n",
    paste(archivos_faltantes, collapse = "\n")
  )
}

data_all <- data.table::rbindlist(
  lapply(archivos_mortalidad, data.table::fread),
  use.names = TRUE,
  fill = TRUE
) %>%
  as_tibble()

# países con datos para todo el periodo

paises <- data.frame(
  Country = c(2045, 2140, 2190, 2250, 2280, 2340, 2350),
  Pais = c(
    "Belice",
    "Costa Rica",
    "El Salvador",
    "Guatemala",
    "Honduras",
    "Nicaragua",
    "Panama"
  )
)

# filtramos país, años y formato ICD-10

data_ca <- data_all %>%
  filter(Country %in% paises$Country) %>%
  left_join(paises, by = "Country")

# cargamos la exposición del primer script

exposicion_limpia <- readr::read_csv(
  file.path(ruta_salida, "exposicion_limpia.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)

llaves <- c("pais", "year", "age_group", "sex")

# una revisión rápida antes de unir las bases

duplicados_exposicion <- exposicion_limpia %>%
  count(across(all_of(llaves)), name = "n") %>%
  filter(n > 1)

faltantes_exposicion <- exposicion_limpia %>%
  filter(if_any(everything(), is.na))

exposiciones_invalidas <- exposicion_limpia %>%
  filter(is.na(exposure) | exposure <= 0)

stopifnot(
  nrow(duplicados_exposicion) == 0,
  nrow(faltantes_exposicion) == 0,
  nrow(exposiciones_invalidas) == 0
)

# pasamos las muertes a formato largo
# en Frmat == 0, Deaths2,...,Deaths6 son las edades 0,1,2,3,4
# y Deaths7,...,Deaths25 corresponden a 5-9,...,95+

mapa_edades <- setNames(
  c(
    "5-9", "10-14", "15-19", "20-24", "25-29",
    "30-34", "35-39", "40-44", "45-49", "50-54",
    "55-59", "60-64", "65-69", "70-74", "75-79",
    "80-84", "85-89", "90-94", "95+"
  ),
  paste0("Deaths", 7:25)
)

mortalidad_base <- data_ca %>%
  filter(
    Year %in% 2015:2018,
    Sex %in% c(1, 2),
    Frmat == 0
  ) %>%
  mutate(
    pais = Pais,
    year = as.integer(Year),
    sex = recode(
      as.character(Sex),
      "1" = "Male",
      "2" = "Female"
    ),
    deaths_0_4 = rowSums(
      pick(Deaths2:Deaths6),
      na.rm = FALSE
    )
  )

# esta versión conserva las edades simples que usa el EDA de la bitácora 2

catalogo_eda <- read_csv(
  ruta_catalogo_eda,
  col_types = cols(Cause = col_character(), icd10_code = col_double())
)

stopifnot(!anyDuplicated(catalogo_eda$Cause))

mapa_edades_eda <- tibble(
  intervalo_edad = paste0("Deaths", 2:25),
  edad_grupo = c(
    "0", "1", "2", "3", "4", "5-9", "10-14", "15-19",
    "20-24", "25-29", "30-34", "35-39", "40-44", "45-49",
    "50-54", "55-59", "60-64", "65-69", "70-74", "75-79",
    "80-84", "85-89", "90-94", "95+"
  ),
  edad_orden = 1:24
)

eda_base_mortalidad <- mortalidad_base %>%
  select(pais, year, sex, Cause, Deaths2:Deaths25) %>%
  inner_join(catalogo_eda, by = "Cause") %>%
  pivot_longer(
    Deaths2:Deaths25,
    names_to = "intervalo_edad",
    values_to = "muertes"
  ) %>%
  left_join(mapa_edades_eda, by = "intervalo_edad") %>%
  mutate(
    sexo = recode(sex, "Male" = "Hombres", "Female" = "Mujeres"),
    muertes = replace_na(muertes, 0)
  ) %>%
  group_by(
    pais, year, sexo, icd10_code,
    intervalo_edad, edad_grupo, edad_orden
  ) %>%
  summarise(muertes = sum(muertes), .groups = "drop") %>%
  rename(Pais = pais, Year = year)

write_csv(
  eda_base_mortalidad,
  file.path(ruta_salida, "eda_base_mortalidad.csv")
)

mortalidad_0_4 <- mortalidad_base %>%
  transmute(
    Country,
    Admin1,
    SubDiv,
    year,
    List,
    Cause,
    sex,
    Frmat,
    IM_Frmat,
    pais,
    age_group = "0-4",
    deaths = deaths_0_4
  )

mortalidad_5_mas <- mortalidad_base %>%
  select(
    Country,
    Admin1,
    SubDiv,
    year,
    List,
    Cause,
    sex,
    Frmat,
    IM_Frmat,
    pais,
    Deaths7:Deaths25
  ) %>%
  pivot_longer(
    cols = Deaths7:Deaths25,
    names_to = "death_column",
    values_to = "deaths"
  ) %>%
  mutate(
    age_group = unname(mapa_edades[death_column])
  ) %>%
  select(-death_column)

mortalidad_larga <- bind_rows(
  mortalidad_0_4,
  mortalidad_5_mas
)

# dejamos una copia antes de agrupar las causas
write_csv(
  mortalidad_larga,
  file.path(ruta_salida, "mortalidad_larga_centroamerica_2015_2018.csv"),
  na = ""
)

# agrupamos las causas por capítulos de la ICD-10

catalogo_causas <- tribble(
  ~Cause, ~causa_grupo,
  "I", "Enfermedades infecciosas y parasitarias",
  "II", "Tumores",
  "III", "Enfermedades de la sangre y de los órganos hematopoyéticos y ciertos trastornos de la inmunidad",
  "IV", "Enfermedades endocrinas, nutricionales y metabólicas",
  "V-VIII", "Trastornos mentales, enfermedades del sistema nervioso y de los órganos de los sentidos",
  "IX", "Enfermedades del sistema circulatorio",
  "X", "Enfermedades del sistema respiratorio",
  "XI", "Enfermedades del sistema digestivo",
  "XII", "Enfermedades de la piel y del tejido subcutáneo",
  "XIII", "Enfermedades del sistema osteomuscular y del tejido conjuntivo",
  "XIV", "Enfermedades del sistema genitourinario",
  "XV", "Embarazo, parto y puerperio",
  "XVI", "Afecciones originadas en el periodo perinatal",
  "XVII", "Malformaciones congénitas, deformidades y anomalías cromosómicas",
  "XVIII", "Síntomas, signos y hallazgos anormales no clasificados en otra parte",
  "XX", "Causas externas de mortalidad"
)

mortalidad_agrupada <- mortalidad_larga %>%
  filter(Cause != "AAA") %>%
  mutate(
    letra_causa = substr(Cause, 1, 1),
    numero_causa = suppressWarnings(
      as.integer(substr(Cause, 2, 3))
    ),
    Cause = case_when(
      letra_causa %in% c("A", "B") |
        (letra_causa == "R" & numero_causa == 75) ~ "I",
      
      letra_causa == "C" |
        (letra_causa == "D" & between(numero_causa, 0, 48)) ~ "II",
      
      letra_causa == "D" &
        between(numero_causa, 50, 89) ~ "III",
      
      letra_causa == "E" &
        between(numero_causa, 0, 90) ~ "IV",
      
      letra_causa %in% c("F", "G", "H") ~ "V-VIII",
      
      letra_causa == "I" ~ "IX",
      
      letra_causa == "J" ~ "X",
      
      letra_causa == "K" ~ "XI",
      
      letra_causa == "L" ~ "XII",
      
      letra_causa == "M" ~ "XIII",
      
      letra_causa == "N" ~ "XIV",
      
      letra_causa == "O" ~ "XV",
      
      letra_causa == "P" ~ "XVI",
      
      letra_causa == "Q" ~ "XVII",
      
      (
        letra_causa == "R" &
          numero_causa != 75
      ) |
        letra_causa == "U" ~ "XVIII",
      
      letra_causa %in% c("V", "W", "X") |
        (
          letra_causa == "Y" &
            between(numero_causa, 0, 89)
        ) ~ "XX",
      
      TRUE ~ NA_character_
    )
  ) %>%
  select(
    -letra_causa,
    -numero_causa
  ) %>%
  group_by(
    Country,
    Admin1,
    SubDiv,
    year,
    List,
    sex,
    Frmat,
    IM_Frmat,
    pais,
    age_group,
    Cause
  ) %>%
  summarise(
    deaths = sum(deaths, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(
    Country,
    Admin1,
    SubDiv,
    year,
    List,
    sex,
    Frmat,
    IM_Frmat,
    pais,
    age_group
  ) %>%
  complete(
    Cause = catalogo_causas$Cause,
    fill = list(deaths = 0)
  ) %>%
  ungroup() %>%
  left_join(
    catalogo_causas,
    by = "Cause"
  ) %>%
  relocate(
    causa_grupo,
    .after = Cause
  )

# ajustamos la exposición al alcance de mortalidad
# Honduras no tiene mortalidad en 2015-2018
# "Total" no equivale a Sex == 9: el código 9 es sexo desconocido

exposicion_objetivo <- exposicion_limpia %>%
  filter(
    year %in% 2015:2018,
    pais != "Honduras",
    sex %in% c("Male", "Female")
  ) %>%
  mutate(
    pais = recode(
      pais,
      "Belize" = "Belice"
    )
  )

# comprobamos que los estratos calcen antes de unir

estratos_mortalidad <- mortalidad_agrupada %>%
  distinct(across(all_of(llaves)))

estratos_exposicion <- exposicion_objetivo %>%
  distinct(across(all_of(llaves)))

solo_mortalidad <- anti_join(
  estratos_mortalidad,
  estratos_exposicion,
  by = llaves
)

solo_exposicion <- anti_join(
  estratos_exposicion,
  estratos_mortalidad,
  by = llaves
)

cat("Estratos de mortalidad:", nrow(estratos_mortalidad), "\n")
cat("Estratos de exposición:", nrow(estratos_exposicion), "\n")
cat("Solo en mortalidad:", nrow(solo_mortalidad), "\n")
cat("Solo en exposición:", nrow(solo_exposicion), "\n")

stopifnot(
  nrow(solo_mortalidad) == 0,
  nrow(solo_exposicion) == 0
)

# unimos mortalidad y exposición

base_unida <- mortalidad_agrupada %>%
  left_join(
    exposicion_objetivo %>%
      select(
        all_of(llaves),
        exposure
      ),
    by = llaves,
    relationship = "many-to-one"
  )

stopifnot(
  !anyNA(base_unida$exposure)
)

cat("Filas finales:", nrow(base_unida), "\n")
cat(
  "Exposiciones faltantes después de unir:",
  sum(is.na(base_unida$exposure)),
  "\n"
)

# nombres finales de países, sexos y edades

base_final <- base_unida %>%
  select(
    -c(Country, Admin1, SubDiv, List, Frmat, IM_Frmat)
  ) %>%
  rename(
    exposicion = exposure,
    anio = year,
    sexo = sex,
    muertes = deaths,
    grupo_edad = age_group,
    causa = Cause
  ) %>%
  mutate(
    sexo = recode(
      sexo,
      "Female" = "Mujer",
      "Male" = "Hombre"
    )
  ) %>%
  arrange(
    pais,
    anio,
    sexo,
    grupo_edad,
    causa
  )

# guardamos la base que usan los modelos

write_csv(
  base_final,
  file.path(ruta_salida, "data_centroamerica_FINAL.csv"),
  na = ""
)
