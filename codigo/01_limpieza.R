# 01_limpieza.R
# Limpieza y preparación de los datos crudos
# Autor: Kevin calderon
# Fecha: 1/4/2026

library(data.table)
library(tidyr)
library(dplyr)
library(here)

here()
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

# write.csv(data_ca, here("datos", "procesados", "data_centroamerica.csv"), row.names = FALSE)

# 01_limpieza.R
# Limpieza de datos y clasificacion ICD10
# Autor: Benjamin Padua
# Fecha: 26/5/2026



# Creo copia filtrando anios 
data_ca_1 <- data_ca[data_ca$Year %in% 2015:2018,]
# Convertir a factor el int de fecha
data_ca_1$Year <- as.factor(data_ca_1$Year)
## Asignacion de codigo 1001 de ICD10  enfermedades infecciosas y parasitarias
data_ca_1$icd10_code <- NA

data_ca_2 <- data_ca_1 


data_ca_2 <- data_ca_2 %>%
  mutate(
    string  = substr(Cause, 1,1),
    number = as.numeric(substr(Cause,2,3))
    
    )






data_ca_2$number[is.na(data_ca_2$number)] <- 999999 #ASIGNACION ARBITRARIA DE NUMERO GRANDE PARA QUE NO ENTRE EN LAS VALIDACIONES POR NA Y SE SOBREESCRIBA icd10c_code

data_ca_etiquetada <- data_ca_2 %>%
  mutate(
    icd10_code= case_when(
      
      # A00- B99 ICD10 1001
      (string == 'A' & number>=0 & number <=99) ~ 1001,
      (string == 'B') ~ 1001,
      #C00 - C99 y D00- D48 corresponde a ICD10 1026 NEOPLASMA
      
      (string == 'C') ~ 1026,
      (string == 'D' & number <= 48) ~ 1026,
      
      # D50- D89  corresponde a ICD10 1048 ENFERMEDADES EN LA SANGRE
      (string == 'D' & number >= 50 & number <=89) ~ 1048,
      
      #E00 - E90  corresponde a ICD10 1051 ENCDOCRINO ENFERMEDADES METABOLICAS
      (string == 'E') ~ 1051,
      
      # F00- F99  icd 10 1055 desordenes del comportamiento 
      (string == 'F') ~ 1055,
      
      # G00 - G99 ICD 10 1058 ENFERMEDAD SISTEMA NERVIOSO 
      (string == 'G') ~ 1058,
      
      #H00 - H59  ICDD 10 1062 ENFERMEDAD OJO
      (string == 'H' & number <= 59) ~ 1062,
      
      # H60- H95 ICD10 1063 ENFERMEDAD OIDO 
      (string == 'H' & number >= 60 & number <=95) ~ 1063,
      
      # I 00 - I 99  ICD10: 1064 ENFERMEDADES CIRCULATORIAS
      (string == 'I') ~ 1064,
      
      #J00J99 ICD10:1072  ENFERMEDADES SISTEMA RESPIRATORI
      
      (string == 'J') ~ 1072,
      
      # K00-K92 , ICD10:1078 ENFERMEDADES SISTEM DIGESTIVO 
      (string == 'K') ~ 1078,
      
      # L00- L99 ICD10: 1082 ENFERMEDADES SUBCUTANEAS Y DE PIEL
      
      (string == 'L') ~ 1082,
      
      # M00 - M 99 ICD10 : 1083 ENFERMEDADES DEL ESQUELETO
      (string == 'M') ~ 1083,
      
      # N00 - N99  ICD10 : 1084 ENFERMEDADES  GENITICOURINARIAS 
      (string == 'N') ~ 1084,
      
      # O00 - O99 ICD10 : 1087  EMBARAZO NACIMIENTO PREMATURO 
      (string == 'O') ~ 1087,
      
      # P00-P96 ICD10: 1092  CODICIONES PERINATALES
      (string == 'P') ~ 1092,
      
      # Q00-Q99 ICD10 : 1093 MALFORMACIONES CONGENITAS  y deformaciones
      (string == 'Q') ~ 1093,
      
      #R00 R99 ICD10 : 1094  anomalidades clinicas de laboratorio
      
      (string == 'R') ~ 1094,
      
      # V01- V99 : ICD10 1096 accidentes de transporte
      (string == 'V') ~ 1096 ,
      
      # X85 - Y09 : ICD10 1102 ASALTO
      
      (string == 'X' & number >= 85 & number <= 99) ~ 1102,
      (string == 'Y' & number <= 09) ~ 1102,
      
      
      
      
      TRUE ~ NA_real_
    )
  )

#Se hallaron NA.s introducidos por coercion corresponde a AAA muerte por todas las causas codigo 1000 en ICD10

data_ca_etiquetada$icd10_code[data_ca_etiquetada$number == 999999] <-1000

## Eliminar NA restantes 

data_ca_etiquetada <- data_ca_etiquetada[!is.na(data_ca_etiquetada$icd10_code),]


