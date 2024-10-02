library(shiny)
library(bslib)
library(ggplot2)
library(shinychat)
library(elmer)

ui <- page_sidebar(
  title = "R plot alt text generator",
  sidebar = sidebar(
    textAreaInput("code", "Enter R code that generates a plot:", rows = 5),
    actionButton("generate_plot", "Generate visualization and alt text")
  ),
  card(plotOutput("plot"), verbatimTextOutput("error"))
)

server <- function(input, output, session) {
  chat <- elmer::new_chat_openai(system_prompt = "You are an assistant who generates alt text for plots.")
  
  observeEvent(input$generate_plot, {
    output$error <- renderText({
      ""
    })
    
    output$plot <- renderPlot({
      
    })
    
    code <- input$code
    result <- tryCatch({
      eval(parse(text = code))
    }, error = function(e) {
      e
    })
    
    if (inherits(result, "ggplot") || is.null(result)) {
      output$plot <- renderPlot({
        eval(parse(text = code))
      })
    } else {
      output$error <- renderText("Error: The code did not generate a valid plot.")
    }
  })
}

shinyApp(ui, server)
