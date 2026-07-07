library(tidyverse)
library(here)

rutas_wpp <- c(
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.csv"),
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.csv.gz"),
  here("datos", "originales", "WPP2024_PopulationByAge5GroupSex_Medium.gz")
)

ruta <- rutas_wpp[file.exists(rutas_wpp)][1]

if (is.na(ruta)) {
  stop(
    "No se encontro el archivo WPP. Coloque uno de estos archivos en datos/originales/: ",
    paste(basename(rutas_wpp), collapse = ", ")
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


# Códigos ISO-3 de países de Centroamérica
codigos_centroamerica <- c(
  "BLZ", # Belize
  "CRI", # Costa Rica
  "SLV", # El Salvador
  "GTM", # Guatemala
  "HND", # Honduras
  "NIC", # Nicaragua
  "PAN"  # Panamá
)

# Filtrar por país usando ISO-3 y por años 2015-2018
data_filtrada <- data %>%
  filter(
    ISO3_code %in% codigos_centroamerica,
    Time %in% 2015:2018
  )


# Estandarizar edades de 95 en adelante 
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


# Dejar la base de exposición en formato largo y limpio

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



# Exportar base limpia de exposición
readr::write_csv(
  exposicion_limpia,
  here("datos", "procesados", "exposicion_limpia.csv")
)
