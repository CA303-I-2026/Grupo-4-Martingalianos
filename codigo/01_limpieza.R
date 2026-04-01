# 01_limpieza.R
# Limpieza y preparación de los datos crudos
# Autor: Kevin calderon
# Fecha: 1/4/2026

library(data.table)
library(here)
# =========================
# 1. CARGAR TODAS LAS BASES
# =========================

data1 <- read.table(here("datos", "originales", "Morticd10_part1"), sep = ",", header = TRUE)
data2 <- read.table(here("datos", "originales", "Morticd10_part2"), sep = ",", header = TRUE)
data3 <- read.table(here("datos", "originales", "Morticd10_part3"), sep = ",", header = TRUE)
data4 <- read.table(here("datos", "originales", "Morticd10_part4"), sep = ",", header = TRUE)
data5 <- read.table(here("datos", "originales", "Morticd10_part5"), sep = ",", header = TRUE)
data6 <- read.table(here("datos", "originales", "Morticd10_part6"), sep = ",", header = TRUE)

# =========================
# 2. UNIR TODAS LAS BASES
# =========================

data_all <- rbind(data1, data2, data3, data4, data5, data6)

# =========================
# 3. DEFINIR CENTROAMERICA
# =========================

paises <- data.frame(
  Country = c(2045, 2140, 2190, 2250, 2280, 2340, 2350),
  Pais = c("Belice", "Costa Rica", "El Salvador", 
           "Guatemala", "Honduras", "Nicaragua", "Panama")
)

# =========================
# 4. FILTRAR CENTROAM?RICA
# =========================

data_ca <- data_all[data_all$Country %in% paises$Country, ]

# =========================
# 5. AGREGAR NOMBRES
# =========================

data_ca <- merge(data_ca, paises, by = "Country")

# =========================
# 6. GUARDAR BASE DE DATOS
# =========================

write.csv(data_ca, here("datos", "procesados", "data_centroamerica.csv"), row.names = FALSE)