Since 2017, the Consumer Financial Protection Bureau has released consumer complaints against financial corporations. This is a valuable source of information about the problems Americans face in accessing credit, savings, investments.

There are limitations to the data: the people who submit complaints often write them in the heat of anger or at moments of maximal stress. And there is certainly no indication from the CFPB data which of the complaints are legally in the right. But the complaints nevertheless reflect a moment, perhaps fleeting or perhaps sustained, when a person’s expectations of their financial system are mismatched with the reality; a moment where in some fundamental sense, the financial system has failed the people it was putatively designed to serve.

In short, while the complaints database is a somewhat imperfect reflection of financial inclusion, it’s nevertheless useful in conceptualizing our financial system and its discontents. Because the financial system is a product not just of law but also of democratic statecraft, these narratives provide real critiques of how our financial system is failing – even if they have not been subject to legal rulings and are presented without evidence.

[Explore the CFPB Consumer Complaint Database here!](https://jcinterrante.shinyapps.io/CFPBComplaintExplorer/)

Now for the full detail…

# Research Questions
1. What is the spatial distribution of negative sentiments?
2. What topics and products are consumers complaining about?
3. Are institutional characteristics such as asset size correlated with average complaint sentiment?

# Data
1. [CFPB Consumer Complaint Database] (https://www.consumerfinance.gov/data-research/consumer-complaints/#download-the-data)
2. [FDIC Institution-level data] (https://www7.fdic.gov/idasp/warp_download_all.asp)
3. [NCUA Call Report Data] (https://www.ncua.gov/analysis/credit-union-corporate-call-report-data/call-report-forms-instructions-archive)
4. [Census 2000 ZIP Code Tabulation Areas (3 Digit)] (https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.2000.html)

# Methods
My goal for answering my research question was to produce a Shiny app that a user could use to see how the characteristics of a depository institution affected the spatial and graphical distribution of negative sentiments nationwide. To do so, I proceeded through several steps of data cleaning and exploration.

# Data Cleaning
In the original data, institutions are identified by name rather than using their FDIC, FRB or NCUA unique identifier numbers. That made it cumbersome to use institutional predictors to predict complaint volume or sentiment. Hence, the complaint data is effectively an island disconnected from the wealth of thousands of indicators made available in bank and credit union call report filings.

Therefore, a secondary goal for my analysis became to create a data crosswalk between the bank complaint data and other bank/credit union data sources. I took the bank complaint data and added columns from the FDIC and NCUA data, including the unique identifiers of the institution. This process entailed several steps:

1. I converted all institution names to uppercase and removed all punctuation (except spaces) in order to maximize changes of exact matches
To avoid ambiguous matches, I first dropped any institution from FDIC data that shared an identical name with any other institution (The NCUA data did not have duplicates for the subset in my analysis)
2. I left-joined the complaint data with the FDIC bank data and the NCUA credit union data
3. I iteratively examined the unmatched corporations in the complaint data, paying special attention to those that had key words like “bank,” and “union.” Where possible, I manipulated the institution names to achieve matches
4. I dropped all complaints about unmatched companies (these contained credit rating agencies, credit card companies, mortgage lenders, and other non-depository financial institutions that were outside the scope of my analysis)

# Sentiment Analysis
I tested three methods of sentiment analysis: NRC, AFINN, and Bing.

The first step was graphing the sentiment values of individual lemmas (see word_score_afinn and bing). These graphs helped me identify a list of lemmas that had specific technical meanings in financial contexts that should not be assigned sentiment values. These included words such as “money,” “mortgage,” “credit”, and “balance.”

NRC struggled to understand the true sentiments being expressed in the complaint narratives. One would surely not expect the most common sentiments in the set to be “positivity” and “trust,” but that is just the result NRC returned on several test subsets I tried.

AFINN and Bing performed much better. Ultimately, I preferred AFINN for my analysis, because it reflected both the negative/positive polarity of the lemma and also its intensity. This was particularly useful, as language used in complaints ranges from very measured and technical to highly emotionally charged.

# Plotting
I produced three principal visualizations:

1. A choropleth map showing the mean AFFIN score of each ZCTA-3
2. A regression scatter plot in which each point represents a complaint. The log asset size of the target institution is on the x axis and AFINN score is on the y axis. A regression line is overlaid on this graph, and an accompanying regression output gives additional detail.
3. A bar chart showing the raw count of complaints by type

I also produced radar plots of NRC information. I initially intended for these to be included in the Shiny App. However, I dropped them for three reasons:

1. NRC was doing a really poor job of classifying lemmas in this dataset, as discussed above
2. UDPipe returns NRC information in a much longer format than AFFIN. Therefore displaying the radar plots would either require a second parallel dataset, or require the shiny app to do a lot of live filtering, which would then need to be summarized and reformatted for the radar plots. This seemed very inefficient
3. I had to ask: is it worth performing the extra work and very likely harming the performance of my app so that I can produce a type of graph that many data viz experts consider to be [inherently flawed](https://www.darkhorseanalytics.com/blog/radar-more-evil-than-pie)?

Therefore, my final app substituted the NRC radar plot with a graph that shows complaints by time (although TextProcessing.R can still produce the radar plots). I think this was the right call from a user perspective, as many users will want to know: “How many complaints are in my chosen subset and what are they about?”

# App Development
I envision the app’s target audience to be activists and policymakers of varying degrees of technical sophistication who want to understand the problems their constituents have with banking institutions and the overall degree of dissatisfaction with these institutions. As such, I wanted the app to provide several levels of data complexity.

The most basic level is the map, which just shows the mean sentiment of people in that area. Thanks to the builtin features of the tmap package, it can be panned and zoomed very smoothly. For users who want to dig a little deeper, the next graph shows complaints by type. This is a straightforward histogram of complaints in the subset.

Finally, I include a regression plot which shows a very basic regression of average AFINN score on log institution asset size. Although the graph is easy enough for most people to read, the accompanying regression output is starting to verge on a different audience: policy analysts. Depending on the exact context in which this app would be used, it might be wise to drop the regression output as it can be very intimidating.

However, I still felt that even with all these data visualizations, the app was failing to convey one of the best parts of exploring this data: reading the actual complaints. I wanted users to share in the fun. Therefore, I added a button that displays a random complaint when pressed.

# Analysis
My regression analysis was a very simple, single predictor linear model. The outcome variable is AFINN score and the predictor is log(assets). The shiny app allows users to explore how subsetting the data changes this regression, both on a plot and with a traditional regression output. Using the full subset, the linear model finds a statistically significant negative relationship between asset size and complaint positivity. In a regression that uses all the observations in my set, a 1% increase in bank asset size was associated with a 1.272 point decrease to predicted mean AFINN score.

# Limitations and Next Steps
My analysis is a useful first step for a more complex analysis. The crosswalk I built in this project unlocks literally thousands of potential predictors that could be used either for traditional regression analysis or as part of a machine learning project. If we can identify compelling natural experiments, it may even be possible to start drawing causal claims about the determinants of dissatisfaction with banks.

However, what I’ve done so far was a very basic analysis with several limitations:

1. The CFPB only reports complaint data for banks with greater than $10 billion in assets. That means it excludes small-to-midsize community banks.
2. The speed of UDPipe limited the amount of data I could use. My sample used a subset of 1,000 complaint narratives, but the overall dataset contains millions.
3. The app is quite slow to update. I think some of this is inevitable as the shapefile and datasets are large. And I did attempt to mitigate it by adding the “Submit” button which limits the amount of live updating that actually happens. However, I think there are some efficiencies to be gained in the app. In certain places, I do live filtering, sorting, and summarizing. A 2.0 version might be restructured to do some of these cumbersome operations outside of the live functions.