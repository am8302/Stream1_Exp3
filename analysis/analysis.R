# ---- libraries ----
library(plyr)
library(dplyr)
library(farrellLab)
library(farrellMem)
library(ggplot2)
library(tidyr)
library(lme4)

# ---- functions ----


#---- read-data
dat <- read.csv("finalData.csv")

ll<-7

dat$serposf <- dat$serpos # keep continuous version of serpos around
dat$serposf <- factor(dat$serposf)
dat$task_order <- ifelse(dat$task_order<2,0,1)
dat$task_order <- factor(dat$task_order)
dat$task <- factor(dat$task)
dat$correct <- dat$recalled*0
dat$correct[dat$recalled==1 & dat$serposc<ll] <- 1

#---- data-filtering ----
cdat <- ddply(dat, .(ID), function(x) length(unique(x$trial_id)))
smallNSs <- cdat$ID[cdat$V1<= (.8*32)]

# mean correct per participant
recdat <- dat[dat$task=="recall",]
sdat <- ddply(recdat[recdat$serpos<=ll,], .(ID,serposf), summarise, pcor=sum(recalled==1)/length(unique(trial_id)))
ppdat <- ddply(sdat, .(ID), summarise, pcor=mean(pcor))
badSs1 <- ppdat$ID[ppdat$pcor<(1/ll)]

# do the filtering
badFilter <- sapply(dat$ID, function(x) any(x==badSs1) | any(x==smallNSs))
dat <- dat[!badFilter,]

# ---- cond-spc ----
recdat <- dat[dat$task=="recall",]

sdat <- ddply(recdat[recdat$serpos>0 & recdat$serpos<=ll,], .(ID,task_order), function(x) getAccFree(x, ll=7))
plotdat <- ddply(sdat, .(serpos,task_order), summarise, pcor=mean(pcor))

ggplot(plotdat, aes(x=as.numeric(serpos), y=pcor, colour=task_order)) + 
  geom_line() + geom_point(size=4) +
  scale_x_continuous(breaks=1:7)+
  ylim(c(0,1)) + xlab("Serial Position") + ylab("Proportion Correct") + 
  theme_APA() + scale_shape_APA1() + scale_colour_CB() +
  theme(legend.position=c(0.8,0.2))

# plot individuals
ggplot(sdat, aes(x=as.numeric(serpos), y=pcor)) + 
  geom_line() + geom_point(size=4) +
  scale_x_continuous(breaks=1:10)+
  ylim(c(0,0.5)) + xlab("Serial Position") + ylab("Proportion Correct") +  facet_wrap( ~ ID) +
  theme_APA() + scale_shape_APA1() + scale_colour_CB() +
  theme(legend.position=c(0.8,0.2))


# ---- cond-frp ----
sdat <- ddply(recdat[recdat$serpos>0 & recdat$serpos<=ll,], .(ID,task_order), function(x) getFRP(x, ll=6))
plotdat <- ddply(sdat, .(serpos,task_order), summarise, prob=mean(prob))

ggplot(plotdat, aes(x=as.numeric(serpos), y=prob, colour=task_order)) + 
  geom_line() + geom_point(size=4) +
  scale_x_continuous(breaks=1:10)+
  ylim(c(0,0.5)) + xlab("Serial Position") + ylab("FRP") + 
  theme_APA() + scale_shape_APA1() + scale_colour_CB() +
  theme(legend.position=c(0.8,0.2))



## CRP
recdat$trial <- recdat$trial_id

lagCRP <- function (indat, ll){
  
  numer <- rep(0,ll*2-1)
  denom <- rep(0,ll*2-1)
  
  ll1 <- ll - 1
  
  trials <- unique(indat$trial)
  
  indat <- indat[order(indat$trial,indat$outpos),]
  
  for (trial in trials){
    inseq <- as.numeric(indat$serpos[indat$trial==trial & indat$outpos<ll])
    
    if (TRUE){
      pool = setdiff(1:ll, inseq[1])
      if (length(inseq)>1){
        for (i in 2:length(inseq)){
          if (any(pool==inseq[i]) & (inseq[i]>0) & (inseq[i]<=ll) &
              (inseq[i-1]>0) & (inseq[i-1]<=ll)){
            
            numer[inseq[i]-inseq[i-1]+ll] <- numer[inseq[i]-inseq[i-1]+ll]+1
            denom[pool-inseq[i-1]+ll] <- denom[pool-inseq[i-1]+ll]+1
            
            pool <- setdiff(pool,inseq[i])
          }
        }
      }
    }
  }
  numer[ll] <- NA
  
  return(data.frame(lag=c(-(ll-1):0,1:(ll-1)),
                    lagrec=numer/denom))
}

crpdat <- {}

crpdat <- ddply(recdat, .(ID), function(x) lagCRP(x, ll))
plotdat <- ddply(crpdat, .(lag), summarise, pcor=mean(lagrec, na.rm=T))
print(ggplot(plotdat, aes(x=as.numeric(lag), y=pcor)) + 
        geom_line() + geom_point(size=4) +
        scale_x_continuous(breaks=-9:9)+
        ylim(c(0,1)) + xlab("Serial Position") + ylab("FRP") +
        theme_APA() + scale_shape_APA1() +
        theme(legend.position=c(0.8,0.8)))

# ---- memory-for-extremes
recdat <- dat[dat$task=="recall",]

edat <- ddply(recdat, .(ID,trial_id), function(x){
  extag <- rep("other", dim(x)[1])
  mystim <- x$stim[x$serpos>0 & x$serpos<=7]
  extag[which.min(mystim)] <- "min"
  extag[which.max(mystim)] <- "max"
  return(data.frame(x, extag=extag))
         # , 
         #            serpos=x$serpos,
         #            serposf=x$serposf,
         #            outpos=x$outpos,
         #            recalled=x$recalled))
})

ex_mem_ss <- ddply(edat, .(ID,extag), function(x) dim(x[x$recalled==1,])[1]/dim(x[x$recalled==1 | x$recalled==0,])[1])
ex_mem <- ex_mem_ss %>% group_by(extag) %>%
  summarise(mean = mean(V1))

# ---- scores-per-trial
evdat <- ddply(dat, .(ID,trial_id), function(x){
  recev <- mean(x$stim[(x$recalled!=0) &
                        (x$stim>=0) &
                      (x$stim<=100)])
  recev <- mean(x$stim[(x$recalled!=0) & (x$recalled >= -1)& # exclude all repitions
                         (x$stim>=0) &
                         (x$stim<=100)])
  recev <- mean(x$stim[(x$recalled!=0) & (x$recalled >= -3)& (x$recalled != -2)&# exclude repitions of correct items but inlcude reps of intrusions 
                         (x$stim>=0) &
                         (x$stim<=100)])
  #recev <- mean(x$stim[(x$recalled==1)])
  presev <- mean(x$stim[x$task=="offer"])
  WTP <- x$WTP[x$task=="offer"][1]
  return(data.frame(task_order=x$task_order[1],recev=recev,presev=presev,WTP=WTP))
})

evdat$WTP[evdat$WTP<1] <- NA
evdat$WTP[evdat$WTP>99] <- NA

library(nlme)
fm <- lme(WTP ~ presev + recev, data = evdat, random = ~ 1 | ID, 
           na.action=na.omit, method="ML", keep.data=T)
summary(fm)

fm0 <- lme(WTP ~ recev + presev, data = evdat[evdat$task_order==0,], random = ~ 1 | ID, 
           na.action=na.omit, method="ML")
fm1 <- lme(WTP ~ recev + presev, data = evdat[evdat$task_order==1,], random = ~ 1 | ID, 
           na.action=na.omit, method="ML")

fmr <- lme(WTP ~ recev, data = evdat, random = ~ 1 | ID, 
           na.action=na.omit, method="ML")

fmp <- lme(WTP ~ presev, data = evdat, random = ~ 1 | ID, 
           na.action=na.omit, method="ML")

anova(fmr, fmp)
anova(fmr,fm)
anova(fmp,fm)


# fm1 <- lme(WTP ~ recev, data = evdat, random = ~ 1 | ID, na.action=na.omit, method="ML")
# fm2 <- lme(WTP ~ presev, data = evdat, random = ~ 1 | ID, na.action=na.omit, method="ML")
# anova(fm1,fm2)

# Utility for using presev vs recev?

