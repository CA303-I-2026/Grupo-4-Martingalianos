#!/usr/bin/env Rscript

# corre el análisis completo desde la raíz del repositorio

argumentos_r <- commandArgs(trailingOnly = FALSE)
argumento_archivo <- grep("^--file=", argumentos_r, value = TRUE)
archivo_ejecutor <- if (length(argumento_archivo) > 0) {
  sub("^--file=", "", argumento_archivo[1])
} else {
  file.path(getwd(), "ejecutar_analisis.R")
}

raiz_repositorio <- normalizePath(
  dirname(archivo_ejecutor),
  winslash = "/",
  mustWork = TRUE
)

paquetes_requeridos <- c(
  "data.table", "tidyverse", "here", "readr", "dplyr", "tidyr",
  "ggplot2", "ggsci", "cowplot", "forcats", "scales", "stringr",
  "tibble", "knitr"
)

paquetes_faltantes <- paquetes_requeridos[
  !vapply(paquetes_requeridos, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
]

if (length(paquetes_faltantes) > 0) {
  stop(
    "Faltan paquetes requeridos por el análisis:\n",
    paste(paquetes_faltantes, collapse = "\n"),
    "\nEjecute renv::restore() desde la raíz del repositorio."
  )
}

directorio_codigo <- file.path(
  raiz_repositorio,
  "proyecto_final",
  "codigo_final"
)

orden_ejecucion <- c(
  "01_limpieza_exposicion.R",
  "02_limpieza_mortalidad.R",
  "03_graficos.R",
  "04_enfoque_clasico.R",
  "05_analisis_clasico.R",
  "06_enfoque_bayesiano_alpha_beta.R",
  "07_enfoque_bayesiano_simulaciones_qx.R",
  "08_analisis_bayesiano.R",
  "09_comparacion_enfoques.R"
)

archivos_codigo <- file.path(directorio_codigo, orden_ejecucion)
archivos_faltantes <- archivos_codigo[!file.exists(archivos_codigo)]

if (length(archivos_faltantes) > 0) {
  stop(
    "Faltan scripts necesarios para ejecutar el análisis:\n",
    paste(archivos_faltantes, collapse = "\n")
  )
}

directorio_desarrollo <- file.path(raiz_repositorio, "codigo")
pares_desarrollo <- file.path(directorio_desarrollo, basename(archivos_codigo))

if (all(file.exists(pares_desarrollo))) {
  diferencias <- tools::md5sum(archivos_codigo) != tools::md5sum(pares_desarrollo)
  if (any(diferencias)) {
    stop(
      "Las copias de codigo/ y proyecto_final/codigo_final/ no coinciden:\n",
      paste(basename(archivos_codigo[diferencias]), collapse = "\n")
    )
  }
}

directorio_anterior <- getwd()
on.exit(setwd(directorio_anterior), add = TRUE)
setwd(raiz_repositorio)

inicio <- Sys.time()
message("Inicio del pipeline: ", format(inicio, "%Y-%m-%d %H:%M:%S"))
message("Simulaciones bayesianas: ", Sys.getenv("N_SIM_BAYES", "10000"))
message("Semilla bayesiana: ", Sys.getenv("SEMILLA_BAYES", "122"))

for (i in seq_along(archivos_codigo)) {
  message(sprintf("[%d/%d] %s", i, length(archivos_codigo), orden_ejecucion[i]))
  sys.source(archivos_codigo[i], envir = .GlobalEnv, chdir = FALSE)
}

fin <- Sys.time()
message(
  "Pipeline completado en ",
  round(as.numeric(difftime(fin, inicio, units = "mins")), 2),
  " minutos."
)
