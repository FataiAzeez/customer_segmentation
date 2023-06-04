#------------------------------------------------
#           initializing the library
#------------------------------------------------

library(cluster)
library(factoextra)
library(tidyverse)
library(corrplot)
library(GGally)
#library(ggplot2)



# importing the store data set
store_data <- read.csv("data.csv")


# checking if there are null value in the dataset
sum(is.null(store_data))

# Checking for NA in the dataset
any(is.na(store_data))
sum(is.na(store_data))

#removing NA value from the dataset
store_data <- na.omit(store_data)

# view the dataset top rolls
head(store_data)

#checking the column data types
sapply(store_data, class)

# removing rows that are not needed (StockID, Country and Description)
store_df <- store_data[c('InvoiceNo', 'Quantity', 'InvoiceDate', 'UnitPrice', 'CustomerID')]

# checking the summary of the data
summary(store_df)

#---------------------------------------------------
# Reshaping/Tranforming  the dataset
#----------------------------------------------------

# getting the total amount spent by each customer
Amount_spent <- store_data %>%
                  group_by(CustomerID) %>%
                  summarise(Total_amount = sum(UnitPrice * Quantity))

# saving the result as dataframe 
Amount_spent <- as.data.frame(Amount_spent)


# Creating total quantity of goods purchase by each customer
Total_quantity <- store_data %>%
                  group_by(CustomerID) %>%
                  summarise(Total_quantity_purchased = sum(Quantity))

Total_quantity <- as.data.frame(Total_quantity)

# getting quantity purchase each year for each customer
# convert the InvoiceDate column to datetime from character type and extracting only the year
store_df$InvoiceDate <- format(as.POSIXct(store_df$InvoiceDate, format="%m/%d/%Y"),"%Y")

# getting quantity purchase each year
year <- store_df %>%
        group_by(CustomerID, InvoiceDate) %>%
        summarise(sum(Quantity))

year <- as.data.frame(year)


# renaming the column header
year <- year %>% 
  rename(
    "quantity" = "sum(Quantity)"
  )


# reshaping the dataframe to show the total amount spent and quantity purchased 
# each year by customer
cast_year <- reshape2::dcast(year,CustomerID~InvoiceDate, value.var = 'quantity', 
                             fun.aggregate = sum)

# Merging the data frame, joining by CustomerID
new_store_data <- left_join(Amount_spent, cast_year)
new_store_data <- left_join(new_store_data, Total_quantity)


# checking the class or type of the features/columns
sapply(new_store_data, class)

# Checking the new dataframe summary
summary(new_store_data)

# checking for negative values
sum(new_store_data < 0) # counting the number of rows with - values

# replacing the negative values wit NA
new_store_data[new_store_data < 0] <- NA 

# dropping the NAs
new_store_data <- na.omit(new_store_data)


# reorder the new dataframe column by index
new_store_df <- new_store_data[, c(3, 4, 2, 5)]


# checking the dimension of the cleaned dataset
dim(new_store_df)

view(new_store_df)

summary(new_store_df)
#--------------------------------------------------------------------------------------
# Exploring the dataset: Checking the similarities and corollation between the rows
#----------------------------------------------------------------------------------------

#histogram for each attribute
new_store_df %>% 
  gather(Attributes, value, 1:4) %>%
  ggplot(aes(x=value, fill=Attributes)) + 
  geom_histogram(colour="black", alpha=0.5, show.legend=FALSE) +
  facet_wrap(~Attributes, scales="free_x") +
  labs(x="Values", y="Frequency", tittle="Customer Attributes - Histogram plots") +
  theme_bw()



#Density Plot for each attribute
new_store_df %>% 
  gather(Attributes, value, 1:4) %>%
  ggplot(aes(x=value, fill=Attributes)) + 
  geom_density(colour="black", alpha=0.5, show.legend=FALSE) +
  facet_wrap(~Attributes, scales="free_x") +
  labs(x="Values", y="Density", tittle="Customer Attributes - Density plots") +
  theme_bw()


#Box Plot for each attribute
new_store_df %>% 
  gather(Attributes, values, c(1:4)) %>%
  ggplot(aes(x=reorder(Attributes, values, FUN=median), y=values, fill=Attributes)) + 
  geom_boxplot(show.legend=FALSE) +
  labs(tittle="Customer Attributes - Boxplots") +
  theme_bw() + 
  theme(axis.title.y=element_blank(),
        axis.title.x=element_blank()) +
  ylim(0, 35) +
  coord_flip()


# Correlation matrix 
corrplot(cor(new_store_df), tl.cex=0.9)


# Relationship between Total_amount  and Total_quantity_purchased
ggplot(new_store_df, aes(x=Total_amount, y=Total_quantity_purchased)) +
  geom_point() +
  geom_smooth(method="lm", se=FALSE) +
  labs(title="Customer Attributes",
       subtitle="Relationship between Total Amount and Total Quantity") +
  theme_bw()

# Relationship between Total_amount  and Total_quantity_purchased
ggplot(new_store_df, aes(x=Total_amount, y=`2011`)) +
  geom_point() +
  geom_smooth(method="lm", se=FALSE) +
  labs(title="Customer Attributes",
       subtitle="Relationship between Total Amount and Total Quantity") +
  theme_bw()


#------------------------------------------------------------------
# DATA ANALYSIS
#------------------------------------------------------------------

# scaling the data
new_store_df <- scale(new_store_df)

# Perform PCA on the data using prcomp() to reduce the corollation between variables
pca <- prcomp(new_store_df, center = TRUE, scale. = TRUE)

# Extract the whitened data from the pca object
data_whitened <- pca$x

# checking the corrolation after performing pca on the data
corrplot(cor(data_whitened), tl.cex=0.9)

# Checking the Cluster tendency of the dataset
tendency <- get_clust_tendency(data_whitened, 50, graph = TRUE)

# the result is between 0 and 1 with 1 or close to 1 means it's clusterable
tendency$hopkins_stat


#------------------------------------------------------------------------------------------------
#         Finding the optimal k value using elbow method and the Average Silhouette method
#------------------------------------------------------------------------------------------------
# finding optimal K value using the elbow Method
fviz_nbclust(data_whitened, kmeans, method = "wss")

# finding optimal K value using the Average Silhouette Method
fviz_nbclust(data_whitened, kmeans, method = "silhouette")

#---------------------------------------------------------------
#             Performing kmeans Clustering using the k = 2
#---------------------------------------------------------------
set.seed(234)
final_customer_cluster <- kmeans(data_whitened, centers = 2, nstart = 25)

# Total within cluster sum of square
final_customer_cluster$tot.withinss

# Cluster size
final_customer_cluster$size

new_store_data$cluster <- final_customer_cluster$cluster
head(new_store_data, 6)

# Mean values of each cluster
aggregate(data_whitened, by=list(final_customer_cluster$cluster), mean)


# Clustering 
ggpairs(cbind(as.data.frame(data_whitened), Cluster=as.factor(final_customer_cluster$cluster)),
        columns=1:4, aes(colour=Cluster, alpha=0.5),
        lower=list(continuous="points"),
        upper=list(continuous="blank"),
        axisLabels="none", switch="both") +
  theme_bw()


#--------------------------------------------
#            Visualizing the cluster
#--------------------------------------------
theme_set(theme_minimal())
fviz_cluster(final_customer_cluster, data = data_whitened, ellipse.type = "convex", palette = "jco", repel = TRUE, stand = FALSE)

