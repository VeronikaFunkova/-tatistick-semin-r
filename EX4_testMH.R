library(randomForest)
library(parallel)
data(LetterRecognition, package = "mlbench")
set.seed(seed = 123, "L'Ecuyer-CMRG")

n = nrow(LetterRecognition)
n_test = floor(0.2 * n)
i_test = sample.int(n, n_test)
train = LetterRecognition[-i_test, ]
test = LetterRecognition[i_test, ]


ntree = 200
nfolds = 10
mtry_val = 1:(ncol(train) - 1)
folds = sample( rep_len(1:nfolds, nrow(train)), nrow(train) )                   #each observation randomly put into one of  1:10 folds
cv_df = data.frame(mtry = mtry_val, incorrect = rep(0, length(mtry_val)))
cv_pars = expand.grid(mtry = mtry_val, f = 1:nfolds)                            #table that combines all combination of folds and mtry
fold_err = function(i, cv_pars, folds, train) {
  mtry = cv_pars[i, "mtry"]                                                     #given i - which mtry I will use
  fold = (folds == cv_pars[i, "f"])                                             #given i I will use fold(i) - this gives all rows from train data that are in fold i
  rf.all = randomForest(lettr ~ ., train[!fold, ], ntree = ntree,               #random forest No.1
                        mtry = mtry, norm.votes = FALSE)
  pred = predict(rf.all, train[fold, ])                                         #prediction on fold data given the random forest
  sum(pred != train$lettr[fold])                                                #prediction error
}

nc = as.numeric(commandArgs(TRUE)[1])                                           #setting n.cores
cat("MH test: Running with", nc, "cores\n")
system.time({
  cv_err = parallel::mclapply(1:nrow(cv_pars), fold_err, cv_pars, folds = folds,
                              train = train, mc.cores = nc)                     #do fold_err for each combination of fold (1:10 groups) and mtry (1:16 branches for forest)                   
  err = tapply(unlist(cv_err), cv_pars[, "mtry"], sum)                          #number of wrong predictions for each mtry (sum over all different folds))
})
#pdf(paste0("rf_cv_mc", nc, ".pdf")); plot(mtry_val, err/(n - n_test)); dev.off()

#rf.all = randomForest(lettr ~ ., train, ntree = ntree)                          #random forest No.2 - this random forest we have to parallelize
ntreep = lapply(splitIndices(ntree, nc), length)
rfp = function(x) randomForest(lettr ~ ., train, ntree=x, norm.votes = FALSE)
rf.out = mclapply(ntreep, rfp, mc.cores = nc)
rf.all = do.call(combine, rf.out)

#pred = predict(rf.all, test)
crows = splitIndices(nrow(test), nc) 
predp = function(x) as.vector(predict(rf.all, test[x, ]))
cpred = mclapply(crows, predp, mc.cores = nc)
pred = do.call(c, cpred) 

correct <- sum(pred == test$lettr)

mtry = mtry_val[which.min(err)]
#rf.all = randomForest(lettr ~ ., train, ntree = ntree, mtry = mtry)             #random forest No.3 - this random forest we have to parallelize.
rfp2 = function(x) randomForest(lettr ~ ., train, ntree=x, mtry = mtry, norm.votes = FALSE)
rf.out = mclapply(ntreep, rfp2, mc.cores = nc)
rf.all = do.call(combine, rf.out)

#pred_cv = predict(rf.all, test)
cpred_cv = mclapply(crows, predp, mc.cores = nc)
pred_cv = do.call(c, cpred_cv) 

correct_cv <- sum(pred_cv == test$lettr)
cat("Proportion Correct: ", correct/n_test, "(mtry = ", floor((ncol(test) - 1)/3),
    ") with cv:", correct_cv/n_test, "(mtry = ", mtry, ")\n", sep = "")
