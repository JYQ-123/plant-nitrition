# 加载必要的包
library(ggplot2)
library(readxl)
library(rms)  #用于回归建模和生存分析
library(survival)  #用于生存分析的基础包
library(patchwork) #用于将多个图形排列在一起

# 读入数据
data <- read_xlsx("data.xlsx")

# 将分类变量转为因子类型
varsToFactor <- c('sex', 'exercise', 'drink', 'smoke', 'fatty_liver')
data[varsToFactor] <- lapply(data[varsToFactor], factor)

# 设置数据分布
dd <- datadist(data)
options(datadist = "dd") #设置全局选项，以便rms包在建模时使用数据分布信息dd


# 将 P 值转换为科学计数法的通用函数
format_p_value <- function(p, name) {
  if (p < 0.001) {
    return(paste0(name, '<0.001'))  # 返回小于0.001的格式
  } else if (p < 0.01) {
    p = formatC(p, format = "e", digits = 2)  # 转换为科学计数法
    p = strsplit(p, "e")[[1]]  # 拆分为系数和指数
    return(paste0(name, '~"="~', p[1], '~"\u00d7"~10^', p[2]))  # 返回格式化字符串
  } else {
    return(paste0(name, '~"="~', round(p, 2)))  # 返回常规格式
  }
}

## p1: ALT-------------------------------------------------------------------------
# 定义变量
variable <- "ALT"
# 定义协变量（例如：age、sex）
covariates <- c("age", "sex", "drink", "smoke", "BMI", "fatty_liver", "exercise")

#-------------------------------------------------------------------------------
# 拟合模型(HR)
hr_formula <- as.formula(paste("Surv(time, incident) ~ rcs(", variable, ",", 4, ") +", paste(covariates, collapse = " + ")))
hr_fit <- cph(hr_formula, data = data)

# 提取 HR P-overall 和 P-non-linear
hr_p_overall <- anova(hr_fit)[1, 3]  # 第一行的P值
hr_p_nonlinear <- anova(hr_fit)[2, 3]  # 第二行的P值

# 生成 HR 预测值
hr_pred <- Predict(hr_fit, name = variable, fun = exp)

#-------------------------------------------------------------------------------
# 拟合模型(Mortality)
mortality_formula <- as.formula(paste("Surv(time, mortality) ~ rcs(", variable, ",", 4, ") +", paste(covariates, collapse = " + ")))
mortality_fit <- cph(mortality_formula, data = data)

# 提取 Mortality P-overall 和 P-non-linear
mortality_p_overall <- anova(mortality_fit)[1, 3]  # 第一行的P值
mortality_p_nonlinear <- anova(mortality_fit)[2, 3]  # 第二行的P值

# 生成 Mortality 的预测值
mortality_pred <- Predict(mortality_fit, name = variable, fun = exp)

#-------------------------------------------------------------------------------
# 绘制 Mortality 的小图
mortality_plot <- ggplot(mortality_pred, aes(x = variable, y = yhat)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#d2e9cd") +
  geom_line(color = "#aacb96", size = 0.5) +
  geom_hline(yintercept = 1, linetype = 2, size = 0.3) +
  # 使用annotate添加Pnon-linear和Poverall
  annotate(geom = "text", x = min(mortality_pred[[variable]]), y = 1.1*max(mortality_pred$upper),
           label = format_p_value(mortality_p_nonlinear, "Pnon-linear"),
           parse = T, size = 4, hjust = 0) +
  annotate(geom = "text", x = min(mortality_pred[[variable]]), y = 0.8*max(mortality_pred$upper),
           label = format_p_value(mortality_p_overall, "Poverall"),
           parse = T, size = 4, hjust = 0) +
  labs(x = NULL, y = "Mortality") + 
  theme_classic() + 
  theme(panel.background = element_rect(fill = "transparent", color = NA),  # 面板背景透明
        plot.background = element_rect(fill = "transparent", color = NA),  # 绘图区域背景透明
        plot.caption = element_blank(),
        plot.margin = unit(c(0, 0, 0, 0), "cm"), # 去掉边距
        axis.text = element_text(size = 12, color = "black"),
        axis.title = element_text(size = 12, color = "black"))  

mortality_plot
#------------------------------------------------------------------------------- 
# 绘制 HR 的主图
hr_plot <- ggplot(hr_pred, aes(x = variable, y = yhat)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#c6e3c5") +
  geom_line(color = "#7abf79", size = 1) +
  geom_hline(yintercept = 1, linetype = 2, size = 0.6) +
  
  # 使用annotate添加Pnon-linear和Poverall
  annotate(geom = "text", x = 0.4*max(hr_pred[[variable]]), y = 3*min(hr_pred$lower),
           label = format_p_value(hr_p_nonlinear, "Pnon-linear"),
           parse = T, size = 5, hjust = 0) +
  annotate(geom = "text", x = 0.4*max(hr_pred[[variable]]), y = 1*min(hr_pred$lower),  
           label = format_p_value(hr_p_overall, "Poverall"),          
           parse = T, size = 5, hjust = 0) +
  labs(x = variable, y = "HR (95% CI)") +
  theme_classic() +
  theme(plot.caption = element_blank(),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 14, face = "bold", color = "black")) +
  
  # 插入小图
  annotation_custom(
    ggplotGrob(mortality_plot), 
    xmin = min(hr_pred[[variable]]),  # 小图的x轴起始位置
    xmax = min(hr_pred[[variable]]) + 0.7 * (max(hr_pred[[variable]]) - min(hr_pred[[variable]])),  # 小图的x轴结束位置
    ymin = max(hr_pred$upper) - 0.5 * (max(hr_pred$upper) - min(hr_pred$lower)),  # 小图的y轴起始位置
    ymax = max(hr_pred$upper) + 0.1 * (max(hr_pred$upper) - min(hr_pred$lower))) # 小图的y轴结束位置

hr_plot

p1 <- hr_plot


rm(hr_fit, mortality_fit, hr_pred, mortality_pred, mortality_plot, hr_plot)
## p2: AST-------------------------------------------------------------------------
# 定义变量
variable <- "AST"
# 定义协变量（例如：age、sex）
covariates <- c("age", "sex", "drink", "smoke", "BMI", "fatty_liver", "exercise")

#-------------------------------------------------------------------------------
# 拟合模型(HR)
hr_formula <- as.formula(paste("Surv(time, incident) ~ rcs(", variable, ",", 4, ") +", paste(covariates, collapse = " + ")))
hr_fit <- cph(hr_formula, data = data)

# 提取 HR P-overall 和 P-non-linear
hr_p_overall <- anova(hr_fit)[1, 3]  # 第一行的P值
hr_p_nonlinear <- anova(hr_fit)[2, 3]  # 第二行的P值

# 生成 HR 预测值
hr_pred <- Predict(hr_fit, name = variable, fun = exp)

#-------------------------------------------------------------------------------
# 拟合模型(Mortality)
mortality_formula <- as.formula(paste("Surv(time, mortality) ~ rcs(", variable, ",", 4, ") +", paste(covariates, collapse = " + ")))
mortality_fit <- cph(mortality_formula, data = data)

# 提取 Mortality P-overall 和 P-non-linear
mortality_p_overall <- anova(mortality_fit)[1, 3]  # 第一行的P值
mortality_p_nonlinear <- anova(mortality_fit)[2, 3]  # 第二行的P值

# 生成 Mortality 的预测值
mortality_pred <- Predict(mortality_fit, name = variable, fun = exp)

#-------------------------------------------------------------------------------
# 绘制 Mortality 的小图
mortality_plot <- ggplot(mortality_pred, aes(x = variable, y = yhat)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#f4f2db") +
  geom_line(color = "#e8e5b5", size = 0.5) +
  geom_hline(yintercept = 1, linetype = 2, size = 0.3) +
  # 使用annotate添加Pnon-linear和Poverall
  annotate(geom = "text", x = min(mortality_pred[[variable]]), y = 1.1*max(mortality_pred$upper),
           label = format_p_value(mortality_p_nonlinear, "Pnon-linear"),
           parse = T, size = 4, hjust = 0) +
  annotate(geom = "text", x = min(mortality_pred[[variable]]), y = 0.8*max(mortality_pred$upper),
           label = format_p_value(mortality_p_overall, "Poverall"),
           parse = T, size = 4, hjust = 0) +
  labs(x = NULL, y = "Mortality") + 
  theme_classic() + 
  theme(panel.background = element_rect(fill = "transparent", color = NA),  # 面板背景透明
        plot.background = element_rect(fill = "transparent", color = NA),  # 绘图区域背景透明
        plot.caption = element_blank(),
        plot.margin = unit(c(0, 0, 0, 0), "cm"), # 去掉边距
        axis.text = element_text(size = 12, color = "black"),
        axis.title = element_text(size = 12, color = "black"))  

mortality_plot
#------------------------------------------------------------------------------- 
# 绘制 HR 的主图
hr_plot <- ggplot(hr_pred, aes(x = variable, y = yhat)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = "#f5e29d") +
  geom_line(color = "#eabd1d", size = 1) +
  geom_hline(yintercept = 1, linetype = 2, size = 0.6) +
  
  # 使用annotate添加Pnon-linear和Poverall
  annotate(geom = "text", x = 0.4*max(hr_pred[[variable]]), y = 1.2*min(hr_pred$lower),
           label = format_p_value(hr_p_nonlinear, "Pnon-linear"),
           parse = T, size = 5, hjust = 0) +
  annotate(geom = "text", x = 0.4*max(hr_pred[[variable]]), y = 0.5*min(hr_pred$lower),  
           label = format_p_value(hr_p_overall, "Poverall"),          
           parse = T, size = 5, hjust = 0) +
  labs(x = variable, y = "HR (95% CI)") +
  theme_classic() +
  theme(plot.caption = element_blank(),
        axis.text = element_text(size = 14, color = "black"),
        axis.title = element_text(size = 14, face = "bold", color = "black")) +
  
  # 插入小图
  annotation_custom(
    ggplotGrob(mortality_plot), 
    xmin = min(hr_pred[[variable]]),  # 小图的x轴起始位置
    xmax = min(hr_pred[[variable]]) + 0.7 * (max(hr_pred[[variable]]) - min(hr_pred[[variable]])),  # 小图的x轴结束位置
    ymin = max(hr_pred$upper) - 0.5 * (max(hr_pred$upper) - min(hr_pred$lower)),  # 小图的y轴起始位置
    ymax = max(hr_pred$upper) + 0.2 * (max(hr_pred$upper) - min(hr_pred$lower))) # 小图的y轴结束位置

hr_plot

p2 <- hr_plot

# 组合图形
(p1+p2)

# 保存图形
ggsave('RCS.pdf', height = 7, width = 8.5)

