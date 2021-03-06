library(knitr)
library(tidyverse)
library(caret) 
library(randomForest)

# Read Data: Rett, Dup15q, ASD, Placenta ----------------------------------
rettDmrFull <- read.delim("../data/Individual/Rett_sig_individual_smoothed_DMR_methylation.txt", check.names = FALSE)
rettDmrFullCB <- read.delim("../data/Consensus_background/Rett_consensus_background_individual_smoothed_DMR_methylation.txt", check.names = FALSE)
rettInfo <- read.csv("../data/Sample_info/Rett_sample_info.csv") 
rettInfo <- rettInfo %>% add_column(batch = 1)

dupDmrFull <- read.delim("../data/Individual/Dup15q_sig_individual_smoothed_DMR_methylation.txt")
dupDmrFullCB <- read.delim("../data/Consensus_background/Dup_consensus_background_individual_smoothed_DMR_methylation.txt")
dupInfo <- read.csv("../data/Sample_info/Dup15q_sample_info.csv") 
dupInfo <- dupInfo %>% add_column(batch = 2)

asdDmrFull <- read.delim("../data/Individual/ASD_sig_individual_smoothed_DMR_methylation.txt")
asdDmrFullCB <- read.delim("../data/Consensus_background/ASD_consensus_background_individual_smoothed_DMR_methylation.txt")
asdInfo <- read.csv("../data/Sample_info/ASD_sample_info.csv")
asdInfo <- asdInfo %>% add_column(batch = 3)

placentaDmrFull <- read.delim("../data/Individual/sig_individual_smoothed_DMR_methylation.txt")
placentaDmrFullCB <- read.delim("../data/Consensus_background/background_region_individual_smoothed_methylation.txt")
placInfo <- read.csv("../data/Sample_info/sample_info.csv")

# Prepare Data ------------------------------------------------------------
info <- tibble(sampleID = c(as.character(rettInfo$Name), 
                            as.character(dupInfo$Name),
                            as.character(asdInfo$Name)), 
               diagnosis = c(as.character(rettInfo$Diagnosis), 
                             as.character(dupInfo$Diagnosis), 
                             as.character(asdInfo$Diagnosis)), 
               batch = c(as.character(rettInfo$batch), 
                         as.character(dupInfo$batch), 
                         as.character(asdInfo$batch)))

#' cleanData
#' @description Filter (exclude columns "width" to "RawDiff") and transpose DMR dataset
#' @param dmrFull DMR dataset 
#' @import tidyverse
#' @export cleanData
cleanData <- function(dmrFull) {
  data <- dmrFull %>% 
    as.tibble() %>% 
    select(-(width:RawDiff)) %>%
    unite(seqId1, seqnames, start, sep = ":") %>%
    unite(seqId, seqId1, end, sep = "-") %>%
    # transpose: cols to rows
    gather(sampleID, values, -seqId) %>% # cols to rows
    # transpose: rows to cols
    spread(seqId, values)
  return(data)
}

#' cleanData
#' @description select relevant columns from placenta dataset
#' @param dmrFull placenta dataset
#' @import tidyverse
#' @export cleanDataPlacenta
cleanDataPlacenta <- function(dmrFull) {
  data <- dmrFull %>% 
    as.tibble() %>% 
    select(-(width:percentDifference)) %>%
    unite(seqId1, seqnames, start, sep = ":") %>%
    unite(seqId, seqId1, end, sep = "-") %>%
    # transpose: cols to rows
    gather(sampleID, values, -seqId) %>% # cols to rows
    # transpose: rows to cols
    spread(seqId, values)
  return(data)
}

#' cleanData2
#' @description Add diagnosis column for each sample by matching from sample info files and remove sample ID column
#' @param dmrCleanData dataset returned by cleanData()
#' @param sampleInfo sample info dataset
#' @import tidyverse
#' @export cleanData2
cleanData2 <- function(dmrCleanData, sampleInfo) {
  dmrFinalData <- dmrCleanData %>% 
    add_column(diagnosis = sampleInfo$Diagnosis[match(dmrCleanData$sampleID, sampleInfo$Name)], .after = 1) 
  return(dmrFinalData)
}

cleanDataJoinedCB <- function(combat_joinedCB) {
  joinedCB <- combat_joinedCB
  seqId <- row.names(joinedCB)
  joinedCB <- joinedCB %>%
    as.tibble() %>%
    add_column(seqId = seqId, .before = 1) %>%
    gather(sampleID, values, -seqId) %>%
    spread(seqId, values)
  return(joinedCB)
}
joinedDmr <- cleanDataJoinedCB(combat_joinedCB)
cleanData2 <- function(dmrCleanData, sampleInfo) {
  dmrFinalData <- dmrCleanData %>% 
    add_column(diagnosis = sampleInfo$Diagnosis[match(dmrCleanData$sampleID, sampleInfo$Name)], .after = 1) 
  return(dmrFinalData)
}


runClean <- function(dmrFull, sampleInfo, type = NULL) {
  if(type == "plac") {
    dmr <- cleanDataPlacenta(dmrFull)
  } else if (type == "cb") {
    dmr <- cleanDataJoinedCB(dmrFull)
  } else {
    dmr <- cleanData(dmrFull)
  }
  dmr_final <- cleanData2(dmr, sampleInfo)
  return(dmr_final)
}


cbDmr <- runClean(combat_joinedCB, info, type = "cb")
rett <- runClean(rettDmrFull, rettInfo)
dup <- runClean(dupDmrFull, dupInfo)
asd <- runClean(asdDmrFull, asdInfo)
plac <- runClean(placentaDmrFull, placInfo, type = "plac")

# placDmrCB <- cleanDataPlacenta(placentaDmrFullCB)
# pDmrCB <- cleanData2(placDmrCB, placInfo)

#' cleanDataCB
#' @description Filter and transpose consensus background DMR dataset
#' @param dmrFull consensus background DMR dataset 
#' @import tidyverse
#' @export cleanDataCB
cleanDataCB <- function(dmrFull) {
  data <- dmrFull %>% 
    #drop_na() %>%
    as.tibble() %>% 
    #select(-matches("width")) %>% 
    #select(-matches("strand")) %>%
    #unite(seqId1, seqnames, start, sep = ":") %>%
    unite(seqId1, chr, start, sep = ":") %>%
    unite(seqId, seqId1, end, sep = "-") 
  return(data)
}

rettDmrCB <- cleanDataCB(rettDmrFullCB)
dupDmrCB <- cleanDataCB(dupDmrFullCB)
# remove repeated samples: JLKD063 = 1136 , JLKD066 = 1406, JLKD067 = 1711
asdDmrCB <- cleanDataCB(asdDmrFullCB) %>% select(-c("JLKD063", "JLKD066", "JLKD067"))

# joinedCB: combined CB data with diagnosis and batch
joinedCB <- rettDmrCB %>%
  full_join(dupDmrCB, by = "seqId") %>%
  full_join(asdDmrCB, by = "seqId") %>%
  drop_na() %>%
  gather(sampleID, values, -seqId) %>% # transpose: cols to rows
  spread(seqId, values) # transpose: rows to cols
joinedCB <- joinedCB %>%
  add_column(diagnosis = as.factor(info$diagnosis[match(joinedCB$sampleID, info$sampleID)]), .after = 1) %>%
  add_column(batch = as.numeric(info$batch[match(joinedCB$sampleID, info$sampleID)]), .after = 2) %>%
  add_column(sample = as.integer(1:nrow(joinedCB)), .before = 1)
groupedDiagnosis <- as.character(joinedCB$diagnosis)
groupedDiagnosis[which(groupedDiagnosis != "Control")] <- "Positive"
joinedCB <- joinedCB %>% 
  add_column(groupedDiagnosis = as.factor(groupedDiagnosis), .after = 1) 

# adjust for batch effects with Combat in combined concensus background dataset
batch = joinedCB$batch
info_joinedCB = joinedCB[,1:5]
order <- c("sampleID", "sample", "diagnosis", "batch", "groupedDiagnosis")
info_joinedCB <- info_joinedCB[, order] %>% 
  as.data.frame()
row.names(info_joinedCB) <- info_joinedCB$sampleID
info_joinedCB <- info_joinedCB[,2:5]
batch <- info_joinedCB$batch

data_joinedCB <- rettDmrCB %>%
  full_join(dupDmrCB, by = "seqId") %>%
  full_join(asdDmrCB, by = "seqId") %>% 
  drop_na() %>% as.data.frame() 
row.names(data_joinedCB) <- data_joinedCB$seqId
data_joinedCB <- data_joinedCB[,-1] %>% as.matrix.data.frame()

modcombat = model.matrix(~1, data = joined_info)
library(devtools)
library(Biobase)
library(sva)
combat_joinedCB = ComBat(dat = data_joinedCB, batch = batch, mod = modcombat, par.prior = TRUE, prior.plots = FALSE)
View(combat_joinedCB)
write.table(combat_joinedCB, "combat_joinedCB.txt", sep = "\t")


 # Partition data into training and testing --------------------------------
# use p = 0.8, 0.5, 0.2
seed <- 9999
partitionData <- function(dmrDataIn, p) {
  set.seed(seed)
  trainIndex <- createDataPartition(dmrDataIn$diagnosis, 
                                    p = p,
                                    list = FALSE )
  
  training <- dmrDataIn[trainIndex, ]
  testing <- dmrDataIn[-trainIndex, ]
  dmrDataOut <- list("training" = training, "testing" = testing)
  return(dmrDataOut)
}

# Models ------------------------------------------------------------------
# Random forest, Neural networks, ant colony optimization
# particle swarm optimzation, genetic programming
# support vector machine, gradient boosting machine
#fitControl <- trainControl(method = "none", returnResamp = "final")
# used number = 3, repeats = 10 previously
fitControl <- trainControl(method = "repeatedcv", 
                           number = 3, 
                           repeats = 5, 
                           classProbs = TRUE) 
# search = "grid"
# is a linear search through a vector of candidate values, if tuning only 1 parameter

# Model: Random Forest different trControl  ---------------------------
fitRandomForestModel <- function(trainingData) {
  # Model: Random Forest 2-fold Cross Validation ---------------------------
  set.seed(seed)
  rf_model <- train( diagnosis ~ ., 
                     data = trainingData, 
                     method = "rf", 
                     trControl = fitControl )
  # preProcess = "nzv" makes no difference, resampling works
  # tuneGrid = expand.grid(.mtry = mtry)
  return(rf_model)
}

fitNeuralNetworkModel <- function(trainingData) {
  set.seed(seed)
  nn_model <- train( diagnosis ~ ., 
                     data = trainingData, 
                     method = "nnet", 
                     preProcess = c('center', 'scale'), 
                     trControl = fitControl )
  #tuneGrid = expand.grid(size = c(1), decay = c(0.1)) )
}

# Stochasitc gradient boosting
fitGbmModel <- function(trainingData) {
  set.seed(seed)
  gbm_model <- train( diagnosis ~ .,
                      data = trainingData,
                      method = "gbm",
                      trControl = fitControl) #,verbose = FALSE)
  return(gbm_model)
}

# predict the outcome on a test set
predictConfMat <- function(dmrPartData, fitModel, pos) {
  predictModel <- predict(fitModel, dmrPartData$testing)
  probPredict <- predict(fitModel, dmrPartData$testing, type = "prob")
  confMat <- confusionMatrix(predictModel, dmrPartData$testing$diagnosis, positive = pos)
  return(list("confMat" = confMat, "probPreds" = probPredict, "preds" = predictModel))
}

# Feature Selection -------------------------------------------------------
# https://machinelearningmastery.com/feature-selection-with-the-caret-r-package/
# http://dataaspirant.com/2018/01/15/feature-selection-techniques-r/
# https://www.datacamp.com/community/tutorials/feature-selection-R-boruta

# FEATURE SELECTION - Remove highly correlated variables
# before fitting model
removeHighCor <- function(dmrData, cutoffValue){
  set.seed(seed)
  #cutoffValue = 0.90
  dmrData_noDiagnosis <- dmrData[, -1]
  corMatrix <- cor(dmrData_noDiagnosis)
  highCor <- findCorrelation(corMatrix, cutoff = cutoffValue)
  dmrData_noDiagnosis_noHC <- dmrData_noDiagnosis[, -highCor]
  dmrData_noHC <- add_column(dmrData_noDiagnosis_noHC, diagnosis = dmrData$diagnosis, .before = 1)
  return(dmrData_noHC)
}

# FEATURE SELECTION - Variable Importance -----------------------------------
# after fitting model
selectImpVar <- function(dmrData, rf_model, cutoffValue) {
  set.seed(seed)
  varImpList <- varImp(object = rf_model)
  vi <- varImpList[[1]]
  dmrData_vi_rows <- row.names(vi)[which(vi$Overall > cutoffValue)] 
  dmrData_vi_rows <- gsub("`", "", dmrData_vi_rows)
  dmrData_vi <- dmrData[, dmrData_vi_rows]
  dmrData_vi <- add_column(dmrData_vi, diagnosis = dmrData$diagnosis, .before = 1)
  return(dmrData_vi)
  #vi_plot <- plot(dmrData_vi, main = "Random Forest - Variable Importance")
  #vi_plot
}

# freqCut = 95/5 = 19 , uniqueCut = 10 is conservative
# freqCut = 2, uniqueCut = 20 is more aggressive
removeLowVar <- function(dmrData, freqCut = 19, uniqueCut = 10) {
  set.seed(seed)
  nearZeroVar(rDmr[, -1], freqCut = freqCut, uniqueCut = uniqueCut) #default
}

one <- nearZeroVar(rDmr[, -1], freqCut = 19, uniqueCut = 10)
two <- nearZeroVar(rDmr[, -1], freqCut = 2, uniqueCut = 20)

# # FEATURE SELECTION - RFE recursive feature elimination
# control <- rfeControl(functions = rfFuncs, 
#                       method = "cv", 
#                       number = 2)
# error: "need same number of samples in x and y" but they are the same
# results <- rfe(x = training[,-1],
#                y = training[, 1], 
#                sizes = c(1:100), 
#                rfeControl = control)

# Run ---------------------------------------------------------------------

runFunctions <- function(dmrData, p, pos) {
  dmrPart <- partitionData(dmrData, p)
  rfModel <- fitRandomForestModel(dmrPart$training)
  predConfMat <- predictConfMat(dmrPart, rfModel, pos)
  result <- list("rfModel" = rfModel, "confMat" = predConfMat$confMat, "probPreds" = predConfMat$probPreds, "preds" = predConfMat$preds, "testingDiag" = dmrPart$testing$diagnosis)
  return(result)
}

NNrunFunctions <- function(dmrData, p, pos) {
  dmrPart <- partitionData(dmrData, p)
  nnModel <- fitNeuralNetworkModel(dmrPart$training)
  predConfMat <- predictConfMat(dmrPart, nnModel, pos)
  result <- list("nnModel" = nnModel, "confMat" = predConfMat$confMat, "probPreds" = predConfMat$probPreds, "preds" = predConfMat$preds, "testingDiag" = dmrPart$testing$diagnosis)
  return(result)
} 

# resampling error: The data set is too small or the subsampling rate is too large: `nTrain * bag.fraction <= n.minobsinnode` 
GbmRunFunctions <- function(dmrData) {
  dmrPart <- partitionData(dmrData)
  gbmModel <- fitGbmModel(dmrPart$training)
  predConfMat <- predictConfMat(dmrPart, gbmModel)
  result <- list("gbmModel" = gbmModel, "confMat" = predConfMat$confMat, "probPreds" = predConfMat$probPreds, "preds" = predConfMat$preds, "testingDiag" = dmrPart$testing$diagnosis)
  return(result)
}

#GbmRunFunctions(pDmr)

# ROC curve --------------------------------------------------------------
library(ROCR)

rocCurve <- function(dmrResult, name) {
  pred <- prediction(dmrResult$probPreds[name], dmrResult$testingDiag)
  # True positive rate = sensitivity, False positive rate = specificity
  perf <- performance(pred, "tpr", "fpr") # evaluating false negatives not included
  plot(perf, main = paste("ROC Curve for Random Forest Model - ", name))
}

# rocCurve(rDmrResult, name = "Rett")
# rocCurve(dDmrResult, name = "Dup15q")
# rocCurve(aDmrResult, name = "ASD") # gives perfect curve: aDmrResult$probPreds["Control"]
# rocCurve(pDmrResult, name = "idiopathic_autism") # placenta

# different confusion matrices
# caret: confMat <- confusionMatrix(preds, dmrPart$testing$diagnosis)
# Model Metrics: confMatMM <- ModelMetrics::confusionMatrix(dmrPart$testing$diagnosis, preds , cutoff=0.5)


# 5 fold cross validation -------------------------------------------------

# https://stackoverflow.com/questions/48629289/final-model-in-cross-validation-using-caret-package
# https://machinelearningmastery.com/train-final-machine-learning-model/ 
fitControl_5fold <- trainControl(method = "cv", 
                           number = 5, 
                           verboseIter = TRUE,
                           returnResamp = "final",#all
                           savePredictions = "final", #"all"
                           classProbs = TRUE) 

rfModel <- function(dmrData) {
  set.seed(seed)
  model <- train(diagnosis ~ .,
                 data = dmrData[,-1],
                 method = "rf",
                 trControl = fitControl_5fold)
  return(model)
}

rett_rfModel <- rfModel(rett)
dup_rfModel <- rfModel(dup)
asd_rfModel <- rfModel(asd)
plac_rfModel <- rfModel(plac)

rett_rfModel
rett_rfModel$finalModel
rett_rfModel$pred # savePredictions = "final" outputs predicted probabilites for resamples with optimal mtry
confusionMatrix.train(rett_rfModel)

dup_rfModel
dup_rfModel$finalModel
dup_rfModel$pred
confusionMatrix.train(dup_rfModel)

asd_rfModel
asd_rfModel$finalModel
asd_rfModel$pred
confusionMatrix.train(asd_rfModel)

predModel <- predict(asd_rfModel, aDmr)
confusionMatrix(predModel, aDmr$diagnosis) #complete overfitting



# obtained final random forest model for rett
# combined confusion matrix for resamples
# predict on rett_dDmr (make fake dataset that labels "dup15q" as "rett")
rett_dDmr <- dDmr %>% 
  mutate(diagnosis = str_replace(diagnosis, "Dup15q", "Rett"))
predict(rett_rfModel, rett_dDmr)

finalModel_asd <- asd_rfModel$finalModel$votes[,1]
finalModel_cont <- asd_rfModel$finalModel$votes[,2]
order <- asd_rfModel$pred[order(asd_rfModel$pred$rowIndex),]
pred_asd <- order$ASD
pred_cont <- order$Control

df_asd <- data.frame("finalModel_asd" = finalModel_asd, "pred_asd" = pred_asd)
