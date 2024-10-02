library(shiny)
library(bslib)
library(shinychat)
library(elmer)
library(shinyAce)
library(magrittr)
library(png)

readme_url <- "https://raw.githubusercontent.com/ivelasq/rplot-alt-text-generator/main/guidelines.md"
readme_content <- paste(readLines(readme_url, warn = FALSE), collapse = "\n")

ui <- page_sidebar(
  title = "R plot alt text generator",
  sidebar = sidebar(
    width = 500,
    tabsetPanel(
      tabPanel("Generate Plot",
               aceEditor(
                 "code",
                 mode = "r",
                 theme = "textmate",
                 height = "400px",
                 value = "plot(cars)",
                 placeholder = "Enter R code that generates a plot"
               ),
               actionButton("generate_plot", "Generate visualization and alt text")
      ),
      tabPanel("Upload Plot",
               fileInput("plot_upload", "Upload a plot image", accept = c("image/png"))
      )
    )
  ),
  card(plotOutput("plot", height = "400px"), verbatimTextOutput("error")),
  card(
    tags$div(style = "height: 150px; overflow-y: auto;",
             tags$p(id = "alt_text_output", "")
    )
  ),
  tags$script(HTML("
    // Use Shiny to handle custom message to update alt text
    Shiny.addCustomMessageHandler('update_alt_text', function(message) {
      document.getElementById('alt_text_output').innerText = message;
    });
  "))
)

server <- function(input, output, session) {
  chat <- elmer::new_chat_openai(
    model = "gpt-4o-mini",
    system_prompt = paste(
      "Generate a friendly and descriptive alt text for the following plot.",
      "Refer to the following guidelines:\n\n",
      readme_content
    ), 
    echo = TRUE
  )

  plot_generated <- reactiveVal(FALSE)
  uploaded_plot <- reactiveVal(NULL)

  observeEvent(input$generate_plot, {
    plot_generated(TRUE)
    uploaded_plot(NULL)
  })

  observeEvent(input$plot_upload, {
    uploaded_plot(input$plot_upload)
    plot_generated(FALSE)
  })
  
  output$plot <- renderPlot({
    if (plot_generated()) {
      eval(parse(text = input$code))
    } else if (!is.null(uploaded_plot())) {
      img <- readPNG(uploaded_plot()$datapath)
      grid::grid.raster(img)
    }
  })

  output$error <- renderText({
    req(input$generate_plot)
    
    if (input$code == "" && is.null(uploaded_plot())) {
      "Error: No R code entered or file uploaded. Please provide code to generate a plot or upload an image."
    } else if (plot_generated() && !tryCatch({ eval(parse(text = input$code)); TRUE }, error = function(e) FALSE)) {
      "Error: The code did not generate a valid plot."
    } else {
      ""
    }
  })

  observe({
    if (plot_generated()) {
      code <- input$code
      alt_text_response <- chat$chat(paste("Here is the code that generated the plot:", code))
      session$sendCustomMessage("update_alt_text", alt_text_response)
    } else if (!is.null(uploaded_plot())) {
      file_path <- uploaded_plot()$datapath
      alt_text_response <- chat$chat(elmer::content_image_file(file_path), "Please generate an alt text for this plot image.")
      session$sendCustomMessage("update_alt_text", alt_text_response)
    } else {
      session$sendCustomMessage("update_alt_text", "")
    }
  })

  session$onSessionEnded(function() {
    chat$close()
  })
}

shinyApp(ui, server)
