library(tidyverse)
library(fuzzyjoin)
library(dummies)

#Grading comments:
# - Some inconsistent use of spacing and style
# - Good data wrangling
# - Good expansion of text analysis from class



setwd("C:/Users/jcinterrante/Documents/GitHub/final-project-jake-interrante")
raw_data_directory = "./Raw Data/"
processed_data_directory = "./Processed Data/"

format_headers <- function(df){
  colnames(df) <- df %>% 
    colnames()%>%
    tolower()%>%
    str_replace_all(c("[[:punct:]](?!$)" = "_", 
                      "[[:punct:]]$" = "",
                      " " = "_"))
  df
}

data_complaints <- read_csv(paste0(raw_data_directory, "complaints.csv"))%>%
  format_headers()

data_bank <- read_csv(paste0(raw_data_directory, "INSTITUTIONS2.csv"))%>%
  format_headers()

data_cu_fs220 <- read_delim(paste0(raw_data_directory, "FS220.txt"), delim = ",")%>%
  format_headers()

data_cu_desc <- read_delim(paste0(raw_data_directory, "AcctDesc.txt"), delim = ",") %>%
  format_headers()%>%
  filter(tablename == "FS220")

cu_names_data <-read_delim(paste0(raw_data_directory, "Credit Union Branch Information.txt"), delim = ",")%>%
  format_headers()

complaints <- data_complaints %>%
  mutate(
    company = toupper(company),
    company = str_replace_all(
      company,
      c(
        "[[:punct:]]" = "",
        "WELLS FARGO  COMPANY" = "WELLS FARGO BANK NATIONAL ASSOCIATION",
        "CITIBANK NA" = "CITIBANK NATIONAL ASSOCIATION",
        "PNC BANK NA" = "PNC BANK NATIONAL ASSOCIATION",
        "JPMORGAN CHASE  CO" = "JPMORGAN CHASE BANK NATIONAL ASSOCIATION",
        "SANTANDER BANK NATIONAL ASSOCIATION" = "SANTANDER BANK NA",
        "SANTANDER CONSUMER USA HOLDINGS INC" = "SANTANDER BANK NA",
        "TD BANK US HOLDING COMPANY" = "TD BANK NATIONAL ASSOCIATION",
        "MT BANK CORPORATION" = "MT BANK CORP",
        "ATLANTIC UNION BANKSHARES INC" = "ATLANTIC UNION BANKSHARES CORP",
        "HUNTINGTON NATIONAL BANK THE" = "THE HUNTINGTON NATIONAL BANK",
        "PEOPLES UNITED BANK NATIONAL ASSOCIATION" = "PEOPLES UNITED BANK, NATIONAL ASSOCIATION",
        "BANCO POPULAR DE PUERTO RICO" = "BANCO POPULAR DE PUERTO RICO",
        "VALLEY NATIONAL BANCORP" = "VALLEY NATIONAL BCORP",
        "CAPITAL ONE FINANCIAL CORPORATION" = "CAPITAL ONE FINANCIAL CORP",
        "HSBC NORTH AMERICA HOLDINGS INC" = "HSBC BANK USA NATIONAL ASSOCIATION",
        "FIFTH THIRD FINANCIAL CORPORATION" = "FIFTH THIRD BANK NATIONAL ASSOCIATION",
        "BANK OF NEW YORK MELLON CORPORATION THE" = "THE BANK OF NEW YORK MELLON",
        "PEOPLES UNITED BANK, NATIONAL ASSOCIATION" = "PEOPLES UNITED BANK NATIONAL ASSOCIATION",
        "FIRST HORIZON BANK  WEST CONGRESS STREET BRANCH" = "FIRST HORIZON BANK",
        "BANK OF HAWAII CORPORATION" = "BANK OF HAWAII",
        "EASTERN BANK CORPORATION" = "EASTERN BANK"
      )
    )
  ) %>%
  select(complaint_id,1:10)

bkclass_key <- c(N = "occ_commercial_bank",
                 NM = "fdic_commercial_bank",
                 OI = "iba_foreign_charter",
                 SA = "ots_savings_association",
                 SB = "fdic_savings_bank",
                 SM = "frb_commercial_bank")

bank <- data_bank %>%
  filter(active == 1) %>%
  pivot_longer(cols = c(name, namehcr), names_to = "entity_type", values_to = "name")%>%
  mutate(
    name = toupper(name),
    name = str_replace_all(name, "[:punct:]", ""),
    asset = as.numeric(str_replace_all(asset, ",", "")) *1000,
    eq = as.numeric(str_replace_all(eq, ",", "")) * 1000,
    dep = as.numeric(str_replace_all(dep, ",", "")) * 1000,
    dummy = 1,
    bkclass = factor(bkclass),
    bkclass = recode_factor(bkclass, !!!bkclass_key)
  )%>%
  select(name, fed_rssd, asset, chrtagnt, dep, eq, fdicsupv, bkclass, dummy) %>%
  filter(name != "")%>%
  pivot_wider(names_from = bkclass, values_from = dummy)%>%
  distinct(name, .keep_all = TRUE)


cu_names <- cu_names_data %>%
  select(cu_number, cu_name)%>%
  distinct()%>%
  mutate(
    cu_name = toupper(cu_name),
    cu_name = str_replace(cu_name, "[:punct:]", "")
  ) %>%
  select(cu_name, cu_number)%>%
  mutate(cu_name = str_replace_all(
    cu_name,
    c("ALLIANT" = "ALLIANT CREDIT UNION",
      "AMERICA FIRST" = "AMERICA FIRST FEDERAL CREDIT UNION",
      "BOEING EMPLOYEES" = "BOEING EMPLOYEES CREDIT UNION",
      "FIRST TECHNOLOGY" = "FIRST TECHNOLOGY FEDERAL CREDIT UNION",
      "THE GOLDEN 1" = "GOLDEN 1 CREDIT UNION THE",
      "PENTAGON" = "PENTAGON FEDERAL CREDIT UNION",
      "SCHOOLSFIRST" = "SCHOOLSFIRST FEDERAL CREDIT UNION",
      "STATE EMPLOYEES" = "STATE EMPLOYEES CREDIT UNION",
      "SUNCOAST" = "SUNCOAST CREDIT UNION",
      "GREAT LAKES" = "GREAT LAKES CREDIT UNION"))
  )


cols <- data_cu_desc$acctname
colnames(data_cu_fs220)[-(1:4)] <- cols
data_cu_fs220 <- format_headers(data_cu_fs220)

credit_unions <- data_cu_fs220 %>%
  select(cu_number,total_assets, total_amount_of_shares_and_deposits)%>%
  left_join(cu_names, by = "cu_number")%>%
  mutate("ncua_credit_union" = 1)

joined <- complaints %>% 
  left_join(bank, by = c("company" = "name"))%>%
  left_join(credit_unions, by = c("company" = "cu_name"))%>%
  unite("assets", c(asset, total_assets), na.rm = TRUE)%>%
  unite("deposits", c(dep, total_amount_of_shares_and_deposits), na.rm = TRUE)

matches <- joined %>%
  filter(!is.na(fed_rssd) | !is.na(cu_number),
         !is.na(consumer_complaint_narrative))

write_csv(matches, paste0(processed_data_directory ,"complaints_cleaned.csv"))
