library(xml2)
library(tidyr)
library(dplyr)
library(jsonlite)
library(data.table)
library(stringr)
setwd('/home/gehau/git/codelijst/src/main/R')
artifactory <- "https://repo.omgeving.vlaanderen.be/artifactory/release"

# read pom.xml 
x <- read_xml("../../../pom.xml")
xml_ns_strip( x )
my_groupId <- xml_text( xml_find_first(x, "/project/groupId") )
my_artifactId <- xml_text( xml_find_first(x, "/project/artifactId") )
my_packageName_ <- paste(my_groupId, my_artifactId, sep = ".")
my_package_id <- paste("omg_package", my_packageName_, sep = ":")
dependencies <- xml_find_all(x, "/project/dependencies/dependency")

df <- read.csv(file = "../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/catalog.csv", sep=",", na.strings=c("","NA"))

df2 <- data.frame(my_package_id, 'spdx:Package', my_packageName_, paste("Package", my_artifactId, sep = " "))
names(df2) <- c("id","type", "packageName", "label")
df <- bind_rows(df, df2)

for (dependency in dependencies){
  groupId <- xml_text( xml_find_first(dependency, "groupId") )
  artifactId <- xml_text( xml_find_first(dependency, "artifactId") )
  version <- xml_text( xml_find_first(dependency, "version") )
  class_path  <- gsub("\\.","/", groupId) 
  packageFileName_ <- paste(artifactId,'-',version,'.jar', sep = "")
  packageName_ <- paste(groupId, artifactId, sep = ".")
  package_id <- paste("omg_package", packageName_, sep = ":")
  downloadLocation_ <- paste(artifactory, class_path, artifactId, version, packageFileName_, sep = "/")
  
  df2 <- data.frame(package_id, 'spdx:Package', downloadLocation_, packageFileName_, packageName_, version, my_package_id, paste("Package", artifactId, sep = " "))
  names(df2) <- c("id","type", "downloadLocation", "packageFileName", "packageName",  "versionInfo", "relationshipType_packageOf", "label")
  df <- bind_rows(df, df2)
  #setDT(df)[id == package_id, downloadLocation := downloadLocation_]
  #setDT(df)[id == package_id, packageFileName := packageFileName_]
  #setDT(df)[id == package_id, packageName := packageName_]
  #setDT(df)[id == package_id, versionInfo := version]
}

#write.csv(df,"../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/catalog.csv", row.names = FALSE)
df <- df %>%
  mutate_all(list(~ str_c("", .)))
for(col in 1:ncol(df)) {   # for-loop over columns
  df <- df %>%
    separate_rows(col, sep = "\\|")
}
df <- df %>% rename(
  "@id" = id,
  "@type" = type
)
context <- jsonlite::read_json("../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/context.json")
df_in_list <- list('@graph' = df, '@context' = context)
df_in_json <- toJSON(df_in_list, auto_unbox=TRUE)
write(df_in_json, "/tmp/catalog.jsonld")
system("riot --formatted=TURTLE /tmp/catalog.jsonld > ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/catalog.ttl")
system("riot --formatted=JSONLD ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/catalog.ttl > ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijst/catalog.jsonld")

