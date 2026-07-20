library(tidyverse)
library(here)

rutas_wpp <- c(
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.csv"),
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.csv.gz"),
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.gz"),
  here(
    "proyecto_final", "datos_final", "originales",
    "WPP2024_PopulationByAge5GroupSex_Medium.csv"
  ),
  here(
    "proyecto_final", "datos_final", "originales",
    "WPP2024_PopulationByAge5GroupSex_Medium.csv.gz"
  ),
  here(
    "proyecto_final", "datos_final", "originales",
    "WPP2024_PopulationByAge5GroupSex_Medium.gz"
  )
)

ruta <- rutas_wpp[file.exists(rutas_wpp)][1]

if (is.na(ruta)) {
  stop(
    "No se encontró el archivo WPP 2024. Se revisaron estas rutas:\n",
    paste(rutas_wpp, collapse = "\n")
  )
}

dir.create(here("datos", "procesados"), recursive = TRUE, showWarnings = FALSE)

data <- readr::read_csv(
  file = ruta,
  col_select = c(
    ISO3_code,
    Location,
    Time,
    AgeGrp,
    PopMale,
    PopFemale,
    PopTotal
  ),
  show_col_types = FALSE,
  name_repair = "unique"
)


# países que sí entran en el análisis
codigos_centroamerica <- c(
  "BLZ", # Belize
  "CRI", # Costa Rica
  "SLV", # El Salvador
  "GTM", # Guatemala
  "HND", # Honduras
  "NIC", # Nicaragua
  "PAN"  # Panamá
)

# nos quedamos con Centroamérica entre 2015 y 2018
data_filtrada <- data %>%
  filter(
    ISO3_code %in% codigos_centroamerica,
    Time %in% 2015:2018
  )


# juntamos las edades de 95 en adelante
data_filtrada_95plus <- data_filtrada %>%
  mutate(
    AgeGrp = case_when(
      AgeGrp %in% c("95-99", "100+") ~ "95+",
      TRUE ~ AgeGrp
    )
  ) %>%
  group_by(
    ISO3_code,
    Location,
    Time,
    AgeGrp
  ) %>%
  summarise(
    PopMale = sum(PopMale, na.rm = TRUE),
    PopFemale = sum(PopFemale, na.rm = TRUE),
    PopTotal = sum(PopTotal, na.rm = TRUE),
    .groups = "drop"
  )


# pasamos la exposición a formato largo

exposicion_limpia <- data_filtrada_95plus %>%
  select(
    iso_3_code = ISO3_code,
    pais = Location,
    year = Time,
    age_group = AgeGrp,
    pop_male = PopMale,
    pop_female = PopFemale,
    pop_total = PopTotal
  ) %>%
  pivot_longer(
    cols = c(pop_male, pop_female, pop_total),
    names_to = "sex",
    values_to = "exposure"
  ) %>%
  mutate(
    sex = case_when(
      sex == "pop_male" ~ "Male",
      sex == "pop_female" ~ "Female",
      sex == "pop_total" ~ "Total"
    ),
    year = as.integer(year),
    iso_3_code = as.character(iso_3_code),
    pais = as.character(pais),
    age_group = as.character(age_group),
    sex = as.character(sex),
    exposure = as.numeric(exposure) * 1000
  ) %>%
  arrange(
    iso_3_code,
    year,
    sex,
    age_group
  )



# guardamos la exposición que usa el resto del análisis
readr::write_csv(
  exposicion_limpia,
  here("datos", "procesados", "exposicion_limpia.csv")
)
