library(shiny)
library(eulerr)

shinyServer(function(input, output, session) {
  inserted <- c()

  observeEvent(input$insert_set, {
    btn <- input$insert_set
    id <- paste0("txt", btn)
    insertUI(
      selector = "#placeholder",
      ui = tags$div(
        splitLayout(
          cellWidths = c("70%", "30%"),
          textInput(paste0("combo_", id), NULL, NULL),
          numericInput(paste0("size_", id), NULL, NULL, min = 0),
          id = id
        )
      )
    )
    inserted <<- c(inserted, id)
  })

  observeEvent(input$remove_set, {
    removeUI(
      selector = paste0("#", inserted[length(inserted)])
    )
    updateTextInput(
      session,
      paste0("combo_", inserted[length(inserted)]),
      NULL,
      NA
    )
    updateNumericInput(
      session,
      paste0("size_", inserted[length(inserted)]),
      NULL,
      NA
    )

    inserted <<- inserted[-length(inserted)]
  })

  # Set up set relationships
  combos <- reactive({
    sets <- sapply(grep("combo_", x = names(input), value = TRUE),
                   function(x) input[[x]])
    size <- sapply(grep("size_", x = names(input), value = TRUE),
                   function(x) input[[x]])

    combos <- as.vector(size, mode = "double")

    names(combos) <- sets
    na.omit(combos)
  })

  euler_fit <- reactive({
    if (input$seed != "")
      set.seed(input$seed)
    euler(combos(), input = input$input_type, shape = input$shape,
          control = list(extraopt = FALSE))
  })

  output$table <- renderTable({
    f <- euler_fit()
    df <- with(f, data.frame(Input = original.values,
                             Fit = fitted.values,
                             Error = regionError))
    colnames(df) <- c("Input", "Fit", "regionError")
    df
  }, rownames = TRUE, width = "100%")

  output$stress <- renderText({
    round(euler_fit()$stress, 2)
  })

  output$diagError <- renderText({
    round(euler_fit()$diagError, 2)
  })

  euler_plot <- reactive({
    ll <- list()

    ll$x <- euler_fit()

    if (!(input$fill == ""))
      ll$fill <- gsub("^\\s+|\\s+$", "", unlist(strsplit(input$fill, ",")))
    if (!is.null(input$title))
      ll$main <- input$title
    if (input$key)
      ll$auto.key <- list(space = input$key_space)
    ll$fontface <- switch(
      input$fontface,
      Plain = 1,
      Bold = 2,
      Italic = 3,
      "Bold italic" = 4
    )
    ll$quantities <- input$quantities
    ll$fill_alpha <- input$alpha
    ll$lty <- switch(input$borders, Solid = 1, Varying = 1:6, None = 0)
    ll$par.settings <- list(
      fontsize = list(text = input$pointsize,
                      points = ceiling(input$pointsize*2/3)))

    do.call(plot, ll)
  })

  output$euler_diagram <- renderPlot({
    euler_plot()
  })

  # Download the plot
  output$download_plot <- downloadHandler(
    filename = function(){
      paste0("euler-", Sys.Date(), ".", input$savetype)
    },
    content = function(file) {
      switch(input$savetype,
             pdf = pdf(file,
                       width = input$width,
                       height = input$height,
                       pointsize = input$pointsize),
             png = png(file, type = "cairo",
                       width = input$width,
                       height = input$height,
                       pointsize = input$pointsize,
                       units = "in",
                       res = 300))
      print(euler_plot())
      dev.off()
    }
  )
})
