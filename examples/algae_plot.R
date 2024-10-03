library(viridis)
library(ggbeeswarm)

data %>%
  ggplot(aes(y = growth_rate, x = light, color = growth_rate)) +
  geom_beeswarm(dodge.width = 1,
                cex = 4,
                size = 4) +
  facet_grid(~ temp) +
  labs(
    x = "LIGHT INTENSITY (LUX)",
    y = "GROWTH RATE",
    title = "ALGAE GROWTH RATES",
    subtitle = "Specific growth rates of algae (divisions per day) at different light intensities and temperatures.",
    caption = "Source: Aquatext"
  ) +
  scale_color_viridis() +
  guides(color = guide_legend(override.aes = list(size = 3))) +
  theme(
    title = element_text(size = 16),
    plot.subtitle = element_text(
      size = 12,
      family = "serif",
      face = "italic"
    ),
    axis.title.x = element_text(size = 10),
    axis.title.y = element_text(size = 10),
    axis.text = element_text(size = 8, face = "italic"),
    plot.caption = element_text(size = 7, face = "italic"),
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 10),
    legend.position = "none"
  )