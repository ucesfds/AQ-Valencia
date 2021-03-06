### Calidad del Aire en Comunitat Valenciana
### 15/02/2019 Valencia, Spain
### Sol Represa
### Archivo 21

## Objetivo trabajar datos de CORINE
# https://land.copernicus.eu/user-corner/technical-library/corine-land-cover-nomenclature-guidelines/html/

library(rgdal)
library(rgeos)
library(GISTools)
library(lubridate)
library(raster)
library(dplyr)


# # # # # # # # # # # # # # # # # # 

# 1) Abrir clases de CORINE

# # # # # # # # # # # # # # # # # # 

CLC <- readOGR("C:\\Users\\narep\\Desktop\\SOL\\AQ-Valencia\\mapa\\CLC2012_CV.shp")


# Abrir shape valencia
shape <- readOGR("C:\\Users\\narep\\Desktop\\SOL\\AQ-Valencia\\mapa\\valencia.shp")
shape <- spTransform(shape, CRS("+proj=utm +zone=30 +ellps=GRS80 +units=m +no_defs "))

CLC <- crop(CLC, shape)  # Recorto imagen para Valencia



# # # # # # # # # # # # # # # # # # # # # # # # # # # 

# 2) Trabajo con df para generar variables utiles

# # # # # # # # # # # # # # # # # # # # # # # # # # # 

CLC_df <- CLC@data
CLC_df$CODE_12 <- as.numeric(levels(CLC_df$CODE_12))[CLC_df$CODE_12]

CLC_df[which(CLC_df$CODE_12 < 200), 4] <- 1 #"Artificial"
CLC_df[which(CLC_df$CODE_12 > 200 & CLC_df$CODE_12 <300), 4] <- 2 #"Agricola"
CLC_df[which(CLC_df$CODE_12 > 300 & CLC_df$CODE_12 <400), 4] <- 3 #"Humedales"
CLC_df[which(CLC_df$CODE_12 > 400), 4] <- 4 #"Agua"

names(CLC_df)[4] <- "Clase"

CLC@data <- CLC_df # Guardar en shape


# # # # # # # # # # # # # # # # # # # # # # # # # # # 

# 3) Generar shapes por categorías iterativo

# # # # # # # # # # # # # # # # # # # # # # # # # # # 


# Uso imagen MODIS MCD19A2 como modelo para crear raster
MCD19A2 <- raster("C:\\Users\\narep\\Desktop\\SOL\\aire_comunitat\\MODIS\\crop_res\\MCD19A2.A2008-01-01.h17v04.tif")

raster_template <- raster(nrows = 239*10, ncols = 158*10, 
                          crs = "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0 ", 
                          ext = extent(MCD19A2))  # toma las extensiones


for( i in 1:4){
  CLC_clase <- CLC[ CLC$Clase == i,] 
  CLC_clase <- spTransform(CLC_clase, CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"))
  
  # 4) Pasar a RASTER 
  rst <- rasterize(CLC_clase, raster_template) # shp a raster

  # Reclasificar: todos los valores > 0 van a ser 1
  recalc <- c(0, 0, 0, 0.001, Inf , 1)  # son col: c[,1] = from; c[,2] = to; c[,3] = becomes 
  rst <- reclassify(rst, recalc)
  
  # 5) Focal operation = sumar
  r_focal <- focal(rst, w = matrix(1, nrow =  3, ncol = 3), fun = sum, na.rm =TRUE) #para que actue sobre un radio de 1.5km
  #plot(r_focal, col = "black")
  
  # 6) Calcular porcentaje > total en matriz = 9
  r_focal <- r_focal*100/9
  #plot(r_focal)
  
  
  # 7) Guardar
  writeRaster(r_focal, file = paste("C:\\Users\\narep\\Desktop\\SOL\\aire_comunitat\\variables\\CLC\\CLC_", i, ".tif", sep=""), format= "GTiff")
  
}
