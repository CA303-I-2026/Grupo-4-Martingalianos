<div align="center">
  <img src="readme_assets/hero_martingalianos.gif" alt="Animación conceptual del proyecto Martingalianos" width="100%">

  <h1>Probabilidades de Decremento Múltiple por Causa de Muerte en Centroamérica, 2015-2018</h1>

  <p>
    <strong>Grupo 04 - Martingalianos</strong><br>
    Universidad de Costa Rica · Escuela de Matemática · Departamento de Matemática y Ciencias Actuariales
  </p>

  <p>
    <img src="https://img.shields.io/badge/R-an%C3%A1lisis%20estad%C3%ADstico-276DC3?style=flat-square&logo=r&logoColor=white" alt="R para análisis estadístico">
    <img src="https://img.shields.io/badge/tidyverse-procesamiento%20de%20datos-1F9E89?style=flat-square&logo=tidyverse&logoColor=white" alt="tidyverse para procesamiento de datos">
    <img src="https://img.shields.io/badge/ggplot2-visualizaci%C3%B3n-3C5488?style=flat-square&logo=ggplot2&logoColor=white" alt="ggplot2 para visualización">
    <img src="https://img.shields.io/badge/Actuar%C3%ADa-decrementos%20m%C3%BAltiples-6A1B9A?style=flat-square" alt="Modelos actuariales de decrementos múltiples">
    <img src="https://img.shields.io/badge/Empirical%20Bayes-modelaci%C3%B3n-8E3B46?style=flat-square" alt="Modelación Empirical Bayes">
    <img src="https://img.shields.io/badge/Quarto-bit%C3%A1coras-39729E?style=flat-square&logo=quarto&logoColor=white" alt="Bitácoras con Quarto">
    <img src="https://img.shields.io/badge/LaTeX-informe%20final-008080?style=flat-square&logo=latex&logoColor=white" alt="Informe final con LaTeX">
  </p>

  <p>
    Proyecto finalizado para el curso <strong>CA0303 Estadística Actuarial</strong>, I ciclo 2026.
  </p>
</div>

---

## Estado del proyecto

Este repositorio reúne el trabajo completo del Grupo 04 - Martingalianos para el curso CA0303 Estadística Actuarial I. El informe y la presentación pueden consultarse directamente en las carpetas de entrega:

| Carpeta | Contenido final | Estado |
|---|---|---|
| [`proyecto_final/`](proyecto_final/) | Informe final en PDF y DOCX, código final, datos finales y figuras seleccionadas | Completo |
| [`presentacion_final/`](presentacion_final/) | Presentación final en PDF, fuente LaTeX y figuras usadas en la defensa | Completo |

**Entregables principales**

| Entregable | Archivo |
|---|---|
| Informe final | [`proyecto_final/Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.pdf`](<proyecto_final/Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.pdf>) |
| Informe DOCX | [`proyecto_final/Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.docx`](<proyecto_final/Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.docx>) |
| Presentación final | [`presentacion_final/presentacion_final.pdf`](presentacion_final/presentacion_final.pdf) |
| Código reproducible final | [`proyecto_final/codigo_final/`](proyecto_final/codigo_final/) |
| Datos finales | [`proyecto_final/datos_final/`](proyecto_final/datos_final/) |

---

## Resumen ejecutivo

La investigación analiza la mortalidad por causa en Belice, Costa Rica, El Salvador, Guatemala, Nicaragua y Panamá durante 2015-2018 desde el marco actuarial de decrementos múltiples. La unidad de análisis es la celda definida por país, sexo, año calendario, grupo etario y capítulo de causa de muerte de la ICD-10.

La pregunta de investigación fue:

> ¿Qué patrones de variabilidad se pueden estimar en la probabilidad de decremento por categoría de causas de la ICD-10 en países centroamericanos durante 2015-2018?

El proyecto estimó la probabilidad anual de decremento por causa mediante dos enfoques:

| Enfoque | Idea central | Uso en el proyecto |
|---|---|---|
| Clásico | Conteos Poisson e intensidades estimadas por exposición | Construir probabilidades de manera sencilla (esencialmente solo se hace una división) |
| Bayesiano | Modelo Poisson-Gamma con hiperparámetros por país y causa estimados mediante Empirical Bayes| Estabilizar celdas con baja exposición, pocos eventos o ceros observacionales, para que no den directamente probabilidad 0 |

Además de la probabilidad absoluta de decremento, se calculó la **composición causal condicionada al fallecimiento**, lo que permite separar dos preguntas distintas: qué tan grande es el riesgo por causa y cómo se reparte causalmente la mortalidad entre quienes fallecen.

---

## Hallazgos principales

| Resultado | Lectura actuarial |
|---|---|
| Alta concordancia global entre el enfoque clásico y el bayesiano | En celdas con suficiente información, ambos métodos conducen a patrones similares |
| Diferencias visibles en celdas frágiles | El enfoque clásico puede asignar probabilidad cero cuando no hay defunciones observadas; el bayesiano conserva estimaciones positivas pequeñas cuando la causa es aplicable |
| Causas externas con mayor peso en hombres jóvenes | Especialmente relevante para interpretar perfiles de mortalidad masculina en edades jóvenes y adultas jóvenes |
| Enfermedades circulatorias con mayor peso en edades avanzadas | El patrón aparece con fuerza en grupos adultos mayores, aunque con variaciones entre países |
| Belice, Costa Rica, El Salvador, Guatemala y Nicaragua muestran perfiles diferenciados | La mortalidad por causa no se comporta como un bloque regional homogéneo |

La base final contiene **15,360 celdas analíticas**. Las mayores discrepancias relativas entre enfoques se concentraron en causas poco frecuentes o de dominio restringido, como embarazo, parto y puerperio; enfermedades osteomusculares; enfermedades de la sangre; enfermedades de la piel; y enfermedades genitourinarias.

<div align="center">
  <table>
    <tr>
      <td align="center" width="50%">
        <img src="proyecto_final/figuras/06_radar_sistema_circulatorio_65-69_hombre.png" alt="Radar de enfermedades del sistema circulatorio en hombres de 65 a 69 años" width="100%">
        <br>
        <sub>Probabilidad local de decremento por enfermedades circulatorias, hombres 65-69.</sub>
      </td>
      <td align="center" width="50%">
        <img src="proyecto_final/figuras/04_composicion_promedio_top4_mas_perinatal.png" alt="Composición causal promedio por edad" width="100%">
        <br>
        <sub>Composición causal promedio por grupo etario.</sub>
      </td>
    </tr>
  </table>
</div>

---

## Metodología

<div align="center">
  <img src="readme_assets/flujo_metodologico.gif" alt="Flujo metodológico conceptual" width="100%">
</div>

### Objeto actuarial

El objeto de interés fue la probabilidad anual de decremento por causa:

```math
q_{x,t}^{(c)} = P\left(T_{x,t}\leq 1,\ J=c\right)
```

donde \(T_{x,t}\) representa el tiempo futuro de vida asociado a una celda demográfica y \(J\) identifica la causa del decremento. El horizonte se fijó en un año por la periodicidad anual de las fuentes de datos.

### Enfoque clásico

Para cada celda y causa se modeló el número de defunciones como:

```math
D_{x,t}^{(c)}\mid\mu_{x,t}^{(c)} \sim \mathrm{Poisson}\left(E_{x,t}\mu_{x,t}^{(c)}\right)
```

La intensidad por causa se estimó por máxima verosimilitud:

```math
\widehat{\mu}_{x,t}^{(c)} = \frac{D_{x,t}^{(c)}}{E_{x,t}}
```

y la probabilidad anual de decremento por la causa \(c\) se obtuvo como:

```math
\widehat{q}_{x,t}^{(c)}
=
\frac{\widehat{\mu}_{x,t}^{(c)}}{\widehat{\mu}_{x,t}^{(\tau)}}
\left(1-e^{-\widehat{\mu}_{x,t}^{(\tau)}}\right)
```

### Enfoque Empirical Bayes

La intensidad se modeló con una distribución Gamma:

```math
\mu_{x,t}^{(c)}
\sim
\mathrm{Gamma}
\left(
\alpha_p^{(c)},\beta_p^{(c)}
\right)
```

Los hiperparámetros se estimaron por país y causa mediante máxima verosimilitud marginal (Empirical Bayes). Después de observar los conteos, la posterior quedó dada por:

```math
\mu_{x,t}^{(c)}\mid D_{x,t}^{(c)},E_{x,t}
\sim
\mathrm{Gamma}
\left(
\widehat{\alpha}_p^{(c)}+D_{x,t}^{(c)},
\widehat{\beta}_p^{(c)}+E_{x,t}
\right)
```

La probabilidad bayesiana de decremento se calculó simulando conjuntamente las intensidades posteriores de todas las causas y transformando cada simulación. Esta decisión evita sustituir medias posteriores en una función no lineal.

### Celdas especiales

Los ceros observacionales se conservaron cuando la causa era posible para la celda. Las celdas fuera del dominio de una causa se excluyeron del ajuste correspondiente como sigue:

| Causa | Tratamiento |
|---|---|
| XV. Embarazo, parto y puerperio | Solo consideramos mujeres en grupos etarios 10-14 a 50-54 |
| XVI. Afecciones originadas en el periodo perinatal | Solo consideramos al grupo etario 0-4 |

---

## Fuentes de datos

| Componente | Fuente | Uso |
|---|---|---|
| Defunciones | [WHO Mortality Database](https://www.who.int/data/data-collection-tools/who-mortality-database) | Conteos por país, sexo, año, edad y causa de muerte |
| Exposición | [World Population Prospects 2024](https://population.un.org/wpp/) | Población a mitad de año como aproximación de exposición |

La base analítica final está en:

```text
proyecto_final/datos_final/procesados/data_centroamerica_FINAL.csv
```

Variables principales:

```text
anio, sexo, pais, grupo_edad, causa, causa_grupo, muertes, exposicion
```

---

## Reproducibilidad

### Requisitos

| Recurso | Uso |
|---|---|
| R 4.5.1 | Versión usada para ejecutar el análisis final |
| `renv` 1.2.3 | Restauración de las versiones exactas de los paquetes |
| [Rtools 4.5](https://cran.r-project.org/bin/windows/Rtools/rtools45/rtools.html) | Necesario en Windows  |
| Quarto | Opcional; necesario para volver a renderizar las bitácoras |
| LaTeX | Opcional; necesario para producir las versiones PDF de los documentos fuente |

Las versiones de los paquetes y sus dependencias se encuentran en [`renv.lock`](renv.lock). El archivo [`sessionInfo.txt`](sessionInfo.txt) registra la sesión con la que se comprobó el entorno. Entre los paquetes principales están `data.table`, `tidyverse`, `here`, `ggplot2`, `ggsci`, `cowplot`, `knitr` y `kableExtra`.

### Preparación del entorno

Desde la raíz del repositorio:

```r
install.packages("renv")
renv::restore()
```


### Ejecución completa

El análisis se ejecuta con un solo archivo. Primero se prepara la exposición (`01_limpieza_exposicion.R`) y luego se construye la base de mortalidad (`02_limpieza_mortalidad.R`).

```bash
Rscript ejecutar_analisis.R
```

La simulación bayesiana utiliza **10,000 iteraciones** y la semilla **122**. Ambos valores pueden modificarse mediante las variables `N_SIM_BAYES` y `SEMILLA_BAYES`; los valores predeterminados son los usados en el análisis final.

El código asociado al informe se conserva en [`proyecto_final/codigo_final/`](proyecto_final/codigo_final/), junto con los datos de la entrega. La carpeta [`codigo/`](codigo/) mantiene la misma versión dentro de la estructura general del curso, con el fin de visibilizar la evolución del trabajo.

### Productos generados

| Producto | Ruta |
|---|---|
| Base unificada final | [`proyecto_final/datos_final/procesados/data_centroamerica_FINAL.csv`](proyecto_final/datos_final/procesados/data_centroamerica_FINAL.csv) |
| Parámetros Empirical Bayes | [`datos/procesados/parametros_bayesianos_alpha_beta.csv`](datos/procesados/parametros_bayesianos_alpha_beta.csv) |
| Resultados clásicos | [`datos/procesados/resultados_enfoque_clasico.csv`](datos/procesados/resultados_enfoque_clasico.csv) |
| Resultados bayesianos | [`datos/procesados/resultados_enfoque_bayesiano.csv`](datos/procesados/resultados_enfoque_bayesiano.csv) |
| Comparación entre enfoques | [`datos/procesados/tabla_01_discrepancia_enfoques.csv`](datos/procesados/tabla_01_discrepancia_enfoques.csv) |
| Comparación de composición causal | [`datos/procesados/tabla_02_composicion_causal.csv`](datos/procesados/tabla_02_composicion_causal.csv) |

---

## Estructura del repositorio

```text
Grupo-4-Martingalianos/
├── README.md
├── ejecutar_analisis.R
├── renv.lock
├── sessionInfo.txt
├── readme_assets/
│   ├── hero_martingalianos.gif
│   └── flujo_metodologico.gif
├── anteproyecto/
│   ├── anteproyecto.pdf
│   ├── anteproyecto.tex
│   └── presentacion.*
├── bitacoras/
│   ├── bitacora_1/
│   ├── bitacora_2/
│   ├── bitacora_3/
│   └── bitacora_4/
├── codigo/
│   ├── 01_limpieza_exposicion.R
│   ├── 02_limpieza_mortalidad.R
│   ├── 03_graficos.R
│   ├── 04_enfoque_clasico.R
│   ├── 05_analisis_clasico.R
│   ├── 06_enfoque_bayesiano_alpha_beta.R
│   ├── 07_enfoque_bayesiano_simulaciones_qx.R
│   ├── 08_analisis_bayesiano.R
│   └── 09_comparacion_enfoques.R
├── datos/
│   ├── originales/
│   └── procesados/
├── figuras/
│   ├── Bayesiano/
│   └── clasico/
├── presentacion_final/
│   ├── presentacion_final.pdf
│   ├── presentacion_final.tex
│   └── figuras/
└── proyecto_final/
    ├── Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.pdf
    ├── Probabilidades de decremento múltiple por causa de muerte en Centroamérica, 2015-2018.docx
    ├── codigo_final/
    ├── datos_final/
    └── figuras/
```

---

## Bitácoras y trazabilidad

| Documento | Contenido | Estado |
|---|---|---|
| [`bitacoras/bitacora_1/`](bitacoras/bitacora_1/) | Definición del problema, pregunta de investigación y delimitación actuarial | Finalizada |
| [`bitacoras/bitacora_2/`](bitacoras/bitacora_2/) | Revisión bibliográfica, antecedentes y restricciones de fuentes | Finalizada |
| [`bitacoras/bitacora_3/`](bitacoras/bitacora_3/) | Desarrollo metodológico: Poisson, enfoque clásico y Empirical Bayes | Finalizada |
| [`bitacoras/bitacora_4/`](bitacoras/bitacora_4/) | Resultados, comparación de enfoques, discusión y cierre | Finalizada |
| [`proyecto_final/`](proyecto_final/) | Informe y paquete reproducible final | Finalizado |
| [`presentacion_final/`](presentacion_final/) | Presentación final de resultados | Finalizada |

---

## Bibliografía y fuentes principales

La bibliografía completa aparece en el informe final. Esta selección resume los pilares metodológicos, actuariales y de datos usados en el proyecto.

| Referencia | Aporte |
|---|---|
| Bowers et al. (1997) | Fundamentos de matemática actuarial y decrementos múltiples |
| Deshmukh (2012) | Modelos de decrementos múltiples implementados en R |
| Keyfitz, Preston & Schoen (1972) | Relación entre tasas y probabilidades en decrementos múltiples |
| Pitacco et al. (2009) | Intensidades, longevidad y modelación actuarial |
| Olivieri & Pitacco (2012) | Tablas de vida y transición hacia enfoques bayesianos |
| Lynch & Brown (2005) | Estimación de tablas de vida con covariables e intervalos |
| Manton et al. (1989) | Empirical Bayes para estabilización de tasas de mortalidad |
| Schmitt, Gilardoni & Andrade (2019) | Modelo jerárquico Poisson-Gamma |
| Schumacher et al. (2022) | Marco bayesiano flexible para mortalidad por edad y causa |
| World Health Organization (2026) | Fuente de defunciones por causa |
| United Nations DESA (2024) | Fuente de exposición poblacional |

<details>
<summary>Bibliografía completa del informe final</summary>

- Austin, P. C., Steyerberg, E. W., & Putter, H. (2021). Fine-Gray subdistribution hazard models to simultaneously estimate the absolute risk of different event types: Cumulative total failure probability may exceed 1. *Statistics in Medicine, 40*(19), 4200-4212. https://doi.org/10.1002/sim.9023
- Bowers, N. L., Gerber, H. U., Hickman, J. C., Jones, D. A., & Nesbitt, C. J. (1997). *Actuarial mathematics* (2nd ed.). Society of Actuaries.
- Calazans, J. A., & Queiroz, B. L. (2020). The adult mortality profile by cause of death in 10 Latin American countries (2000-2016). *Revista Panamericana de Salud Pública, 44*, e1. https://doi.org/10.26633/RPSP.2020.1
- Deshmukh, S. (2012). *Multiple decrement models in insurance: An introduction using R*. Springer. https://doi.org/10.1007/978-81-322-0659-0
- Fine, J. P., & Gray, R. J. (1999). A proportional hazards model for the subdistribution of a competing risk. *Journal of the American Statistical Association, 94*(446), 496-509. https://doi.org/10.1080/01621459.1999.10474144
- Goerlich Gisbert, F. J. (2012). *Tablas de vida de decrementos múltiples: Mortalidad por causas en España (1975-2008)* (Documento de Trabajo No. 1/2012). Fundación BBVA.
- Keyfitz, N., Preston, S. H., & Schoen, R. (1972). Inferring probabilities from rates: Extension to multiple decrement. *Scandinavian Actuarial Journal, 1972*(1), 1-13. https://doi.org/10.1080/03461238.1972.10404630
- Lynch, S. M., & Brown, J. S. (2005). A new approach to estimating life tables with covariates and constructing interval estimates of life table quantities. *Sociological Methodology, 35*(1), 189-237. https://doi.org/10.1111/j.0081-1750.2006.00168.x
- Macdonald, A. S. (1996). An actuarial survey of statistical models for decrement and transition data II: Competing risks, non-parametric and regression models. *British Actuarial Journal, 2*(2), 429-448. https://doi.org/10.1017/S1357321700003469
- Macdonald, A. S., & Richards, S. J. (2025). On contemporary mortality models for actuarial use II: Principles. *British Actuarial Journal, 30*, e19. https://doi.org/10.1017/S1357321725000133
- Manton, K. G., Woodbury, M. A., Stallard, E., Riggan, W. B., Creason, J. P., & Pellom, A. C. (1989). Empirical Bayes procedures for stabilizing maps of U.S. cancer mortality rates. *Journal of the American Statistical Association, 84*(407), 637-650. https://doi.org/10.1080/01621459.1989.10478816
- Olivieri, A., & Pitacco, E. (2012). Life tables in actuarial models: From the deterministic setting to a Bayesian approach. *AStA Advances in Statistical Analysis, 96*, 127-153. https://doi.org/10.1007/s10182-011-0177-y
- Pitacco, E., Denuit, M., Haberman, S., & Olivieri, A. (2009). *Modelling longevity dynamics for pensions and annuity business*. Oxford University Press. https://doi.org/10.1093/oso/9780199547272.001.0001
- Román Sánchez, Y. G., Sánchez Pérez, A. L., & Mendieta Zacarias, I. (2018). Mortalidad por causas en el estado de México, 2000 y 2015. *Novedades en Población, 14*(28), 64-78.
- Schmitt, F. O., Gilardoni, G. L., & Andrade, J. A. A. (2019). A class of flat prior distributions for the Poisson-gamma hierarchical model. *Statistica Neerlandica, 73*(3), 414-433. https://doi.org/10.1111/stan.12176
- Schumacher, A. E., McCormick, T. H., Wakefield, J., Chu, Y., Perin, J., Villavicencio, F., Simon, N., & Liu, L. (2022). A flexible Bayesian framework to estimate age- and cause-specific child mortality over time from sample registration data. *The Annals of Applied Statistics, 16*(1), 124-143. https://doi.org/10.1214/21-AOAS1489
- Society of Actuaries. (2016). *Experience study calculations*. Society of Actuaries.
- United Nations, Department of Economic and Social Affairs, Population Division. (2024). *World Population Prospects 2024*. United Nations. https://population.un.org/wpp/
- Wolbers, M., Koller, M. T., Stel, V. S., Schaer, B., Jager, K. J., Leffondré, K., & Heinze, G. (2014). Competing risks analyses: Objectives and approaches. *European Heart Journal, 35*(42), 2936-2941. https://doi.org/10.1093/eurheartj/ehu131
- World Health Organization. (2026). *WHO Mortality Database*. World Health Organization. https://www.who.int/data/data-collection-tools/who-mortality-database
- Zhang, Y.-Y., Wang, Z.-Y., Duan, Z.-M., & Mi, W. (2019). The empirical Bayes estimators of the parameter of the Poisson distribution with a conjugate gamma prior under Stein's loss function. *Journal of Statistical Computation and Simulation, 89*(16), 3061-3074. https://doi.org/10.1080/00949655.2019.1652606

</details>

---

## Equipo

| Nombre | Carné | Correo institucional |
|---|---|---|
| Sebastián Miranda Ramírez | C4H274 | sebastian.mirandaramirez@ucr.ac.cr |
| Benjamín Gutiérrez Padua | C4F813 | benjamin.gutierrezpadua@ucr.ac.cr |
| Kevin David Calderón Martínez | C4D511 | kevindavid.calderon@ucr.ac.cr |
| Gabriel de Jesús Chaves Esquivel | C4E273 | gabriel.chavesesquivel@ucr.ac.cr |

**Profesor:** Maikol Solís Chacón<br>
**Curso:** CA0303 Estadística Actuarial<br>
**Periodo:** I ciclo de 2026<br>
**Fecha de cierre:** 2026-07-09

---

<div align="center">
  <strong>Grupo 04 - Martingalianos</strong><br>
  <sub>Proyecto finalizado · Universidad de Costa Rica · 2026</sub>
</div>
