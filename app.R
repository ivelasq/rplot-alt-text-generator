library(shiny)
library(bslib)
library(shinychat)
library(elmer)
library(shinyAce)
library(magrittr)
library(ggplot2)
library(png)
library(readr)

readme_url <- "https://raw.githubusercontent.com/ivelasq/rplot-alt-text-generator/main/guidelines.md"
readme_content <- paste(readLines(readme_url, warn = FALSE), collapse = "\n")

ui <- page_sidebar(
  title = "altR",
  theme = bs_theme(base_font = font_google("Lexend"), ),
  sidebar = sidebar(
    width = 500,
    open = "always",
    tabsetPanel(
      tabPanel(
        "Generate Plot",
        HTML("<br>"),
        fileInput("data_file", "Upload Data File (CSV)"),
        textInput("data_object_name", "Name the Data Object", value = "data"),
        actionButton("load_data", "Load Data"),
        textOutput("upload_status"),
        HTML("<br>"),
        aceEditor(
          "code",
          mode = "r",
          theme = "eclipse",
          height = "250px",
          fontSize = "16",
          value = "plot(mtcars$hp)",
          placeholder = "Enter R code that generates a plot"
        ),
        actionButton("generate_plot", "Generate visualization and alt text")
      ),
      tabPanel("Upload Plot", fileInput(
        "plot_upload",
        label = "",
        accept = c("image/png")
      ))
    )
  ),
  card(
    card_header("Plot"),
    plotOutput("plot", height = "400px"),
    verbatimTextOutput("error")
  ),
  card(
    card_header("Generated Alternative Text"),
    tags$div(style = "height: 150px; overflow-y: auto;", tags$p(id = "alt_text_output", ""))
  ),
  tags$script(
    HTML(
      "
    // Use Shiny to handle custom message to update alt text
    Shiny.addCustomMessageHandler('update_alt_text', function(message) {
      document.getElementById('alt_text_output').innerText = message;
    });
  "
    )
  )
)
server <- function(input, output, session) {
  chat <- elmer::new_chat_openai(
    model = "gpt-4o-mini",
    system_prompt = paste(
      "Generate clear, concise, but descriptive alt text for the following plot.",
      "Do not provide commentary or suggestions on how to improve the accessibility.",
      "Refer to the following guidelines:\n\n",
      readme_content,
      "If, and only if, the code does not produce a valid plot, instead, give suggestions on how to fix the code."
    ),
    echo = TRUE
  )
  
  uploaded_data <- reactiveVal(NULL)
  
  observeEvent(input$load_data, {
    req(input$data_file)
    
    data <- tryCatch({
      read_csv(input$data_file$datapath, locale = locale(encoding = "UTF-8"))
    }, error = function(e) {
      showModal(
        modalDialog(
          title = "Error Uploading File",
          "The uploaded file could not be read. Please make sure it is a valid CSV file.",
          easyClose = TRUE
        )
      )
      output$upload_status <- renderText("Failed to upload file.")
      return(NULL)
    })
    
    if (is.null(data)) {
      output$upload_status <- renderText("Failed to upload file.")
      return()
    }
    
    uploaded_data(data)
    assign(input$data_object_name, data, envir = .GlobalEnv)
    output$upload_status <- renderText("File uploaded successfully.")
  })
  
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
    } else if (plot_generated() &&
               !tryCatch({
                 eval(parse(text = input$code))
                 TRUE
               }, error = function(e)
                 FALSE)) {
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
      alt_text_response <- chat$chat(
        elmer::content_image_file(file_path),
        "Please generate an alt text for this plot image."
      )
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
