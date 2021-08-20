library(tidyverse)
library(lubridate)
library(tidytext)
library(SnowballC)
library(udpipe)
library(fmsb)
library(rvest)
library(stringr)
library(RColorBrewer)
library(GISTools)
library(rlang)
library(ggthemes)
getStemLanguages()

setwd("C:/Users/jcinterrante/Documents/GitHub/final-project-jake-interrante")
plot_directory = "./Static Plots/"
shiny_directory = "./Shiny App/"
processed_data_directory = "./Processed Data/"

summarize_nrc <- function(df) {
  df %>%
    group_by(doc_id, nrc) %>%
    summarize(count = n()) %>%
    filter(!is.na(nrc)) %>%
    group_by(doc_id) %>%
    pivot_wider(names_from = "nrc", values_from = count) %>%
    dplyr::select(positive, joy, anticipation, disgust, anger, negative, sadness, fear, surprise, trust) %>%
    ungroup()
}

summarize_bing <- function(df) {
  bing_summary <- df %>%
    mutate(bing = if_else(bing == "positive", 1, -1)) %>%
    group_by(doc_date, doc_id, lemma, term_id, bing) %>%
    summarize()

  for (i in levels(factor(bing_summary$doc_date))) {
    subset <- bing_summary %>%
      ungroup() %>%
      filter(doc_date == i) %>%
      dplyr::select(bing)
  }
  bing_summary
}

summarize_afinn <- function(df) {
  afinn_summary <- df %>%
    group_by(doc_date, doc_id, lemma, term_id, afinn) %>%
    summarize()

  for (i in levels(factor(afinn_summary$doc_id))) {
    subset <- afinn_summary %>%
      ungroup() %>%
      filter(doc_id == i) %>%
      dplyr::select(afinn)
  }
  afinn_summary
}

analyze_sentiments <- function(text, exclude) {
  bis_udp <- udpipe(text$consumer_complaint_narrative, "english")

  doc_dates <- text %>%
    mutate(
      doc_date = date_received,
      doc_id = paste0("doc", row_number())
    )

  bis_udp_output <- bis_udp %>%
    filter(!upos %in% c("PART", "PUNCT", "CCONJ", "SYM", "NUM", "ADP", "AUX", "DET", "PRON", "X", "SCONJ")) %>%
    mutate_if(is.character, str_to_lower) %>%
    left_join(dplyr::select(doc_dates, doc_id, doc_date, complaint_id), by = "doc_id") %>%
    dplyr::select(doc_id, complaint_id, doc_date, term_id, token, lemma, upos) %>%
    mutate(doc_id = factor(doc_id))

  bis_udp_no_stop_words <- bis_udp_output %>%
    anti_join(stop_words, by = c("lemma" = "word")) %>%
    filter(!lemma %in% exclude)

  for (s in c("nrc", "afinn", "bing")) {
    bis_udp_no_stop_words <- bis_udp_no_stop_words %>%
      left_join(get_sentiments(s), by = c("lemma" = "word")) %>%
      plyr::rename(replace = c(sentiment = s, value = s), warn_missing = FALSE)
  }
  bis_udp_no_stop_words
}

generate_summary_plot <- function(data, method) {
  ggplot(data, aes(x = factor(quarter(doc_date, with_year = TRUE)))) +
    labs(
      title = paste0("Overall Positivity of Report (", method, ")"),
      subtitle = "Bar Indicates Average Sentiment",
      x = "Complaint Date",
      y = "Postivity",
      fill = ""
    ) +
    geom_violin(aes(y = eval(sym(method)))) +
    stat_summary(aes(y = eval(sym(method))), color = "chocolate2", fun = "mean", geom = "crossbar", size = 2) +
    #scale_fill_brewer(palette = "Dark2") +
    theme(legend.position = "none")
}

generate_radar_plot <- function(df) {
  nrc_consolidate <- df %>%
    summarize_all(mean, na.rm = TRUE) %>%
    pivot_longer(cols = -doc_id, names_to = "sentiment", values_to = "count") %>%
    mutate(percent = count / sum(count)) %>%
    dplyr::select(sentiment, percent) %>%
    pivot_wider(names_from = sentiment, values_from = percent)

  nrc_names <- nrc_consolidate$doc_date
  nrc_summary2 <- rbind(rep(.2, 10), rep(0, 10), nrc_consolidate) %>%
    mutate(
      across(everything(), ~ replace_na(.x, 0))
    )

  radarchart(nrc_summary2,
    plwd = 2,
    axislabcol = "gray",
    axistype = 1,
    cglcol = "gray", cglty = 1, cglwd = 0.8,
    caxislabels = paste(seq(0, 20, 5), "%"),
    title = "How Often Was a Sentiment Detected as a Percent of All Sentiments?\n(NRC)",
    vlcex = 1,
    plty = 1,
    pfcol = add.alpha(brewer.pal(8, "Pastel2"), 0.3),
    pcol = brewer.pal(8, "Dark2")
  )
}

generate_word_score_plot <- function(df, method) {
  # https://stackoverflow.com/questions/26724124/standard-evaluation-in-dplyr-summarise-a-variable-given-as-a-character-string
  graph_data <- df %>%
    group_by(lemma) %>%
    summarize(score = sum(eval(sym(method)), na.rm = TRUE)) %>%
    arrange(desc(abs(score)))%>%
    head(50)
    #filter(abs(score) >= 5)

  ggplot(graph_data) +
    geom_bar(aes(
      y = reorder(lemma, score), x = score,
      fill = factor(score > 0)
    ),
    stat = "identity"
    ) +
    labs(
      title = paste0("Overall Contribution to Sentiment Score by Word (", method, ")"),
      x = paste0(method, " Score"), y = ""
    ) +
    theme(legend.position = "none")
}

generate_type_plot <- function(df) {
  graph_data <- complaint_sentiments %>%
    group_by(product, sub_product) %>%
    summarize(count = n()) %>%
    ungroup() %>%
    mutate(sub_product = reorder(sub_product, count)) %>%
    filter(!is.na(sub_product))

  ggplot(graph_data, aes(x = sub_product, y = count, fill = product)) +
    geom_bar(stat = "identity") +
    coord_flip() +
    labs(title = "Complaints by Type", x = "") +
    scale_fill_brewer(palette = "Dark2") +
    theme(legend.position = "none")
}

generate_regression_plot <- function(df, predictor = "assets") {
  ggplot(complaint_sentiments, aes(x = log(eval(sym(predictor))), y = afinn)) +
    geom_point() +
    geom_smooth(method = lm) +
    labs(
      title = paste0("AFINN Sentiment Score vs (log) ", predictor, " for the Selected Complaints"),
      x = paste0("log ", predictor),
      y = "Sentiment Score"
    ) +
    theme_calc()
}

data <- read_csv(paste0(processed_data_directory, "complaints_cleaned.csv"), n_max = 1000)

ignore_words <- c(
  "bank", "account", "money", "mail",
  "letter", "mortgage", "score", "pay",
  "money", "payment", "statement", "transaction",
  "credit", "cash", "bank", "account",
  "customer", "balance"
)

sentiments <- analyze_sentiments(data, ignore_words)

nrc_summary <- summarize_nrc(sentiments)
bing_summary <- summarize_bing(sentiments)
afinn_summary <- summarize_afinn(sentiments)

generate_word_score_plot(afinn_summary, "afinn")
ggsave(paste0(plot_directory, "word_score_afinn.png"), width = 4, height = 12)
generate_word_score_plot(bing_summary, "bing")
ggsave(paste0(plot_directory, "word_score_bing.png"), width = 4, height = 12)

generate_summary_plot(afinn_summary, "afinn")
ggsave(paste0(plot_directory,"afinn_summary.png"), width = 20, height = 4)
generate_summary_plot(bing_summary, "bing")
ggsave(paste0(plot_directory,"bing_summary.png"), width = 20, height = 4)

png(file = paste0(plot_directory,"nrc_radar.png"), width = 800, height = 800)
generate_radar_plot(nrc_summary)
dev.off()

summarize_sentiments <- sentiments %>%
  group_by(complaint_id) %>%
  summarize(afinn = sum(afinn, na.rm = TRUE))

complaint_sentiments <- data %>%
  left_join(summarize_sentiments)

generate_type_plot(complaint_sentiments)
ggsave(paste0(plot_directory,"type_plot.png"), width = 6, height = 4)

generate_regression_plot(complaint_sentiments, "assets")
ggsave(paste0(plot_directory,"regression_plot.png"), width = 6, height = 4)

write_csv(complaint_sentiments, paste0(shiny_directory, "complaints_and_sentiments.csv"))
