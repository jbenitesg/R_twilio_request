# Decrypt
decrypt = function(encrypted, key) {
  library(openssl)
  library(base64enc)
  
  BLOCK_SIZE = 16
  key <- charToRaw(key)
  clean = list()
  k = 1
  for (i_encrypted in encrypted) {
    # Convertir el mensaje cifrado de base64 a crudo
    encrypted_raw <- base64_decode(i_encrypted)
    
    # Desencriptar el mensaje
    # Aquí asumimos que el IV está en los primeros 16 bytes del mensaje cifrado
    iv <- encrypted_raw[1:BLOCK_SIZE]
    ciphertext <- encrypted_raw[-(1:BLOCK_SIZE)]
    
    # Desencriptar usando AES en modo CBC
    decrypted_raw <- aes_cbc_decrypt(ciphertext, key = key, iv = iv)
    
    # Convertir el resultado a texto
    clean[[k]] <- rawToChar(decrypted_raw) %>%
      as_tibble()
    k = k + 1
    }
  
  return(
    map_df(.x = clean, .f = dplyr::bind_rows) %>%
      pull()
    )
}

# Launch Twilio messages

launch_twilio_messages <- function(account_sid, account_token,
                                   twilio_number, flow_id,
                                   input_file, batch_size,
                                   sec_between_batches, columns_with_info_to_send) {
  
  library(httr)
  library(jsonlite)
  library(readxl)
  library(openxlsx)
  library(openssl)
  library(tidyverse)
  
  
  # Leer archivo de Excel
  phones_df <- read_excel(input_file)
  
  # Verificar que las columnas necesarias existan
  required_columns <- c("Number", columns_with_info_to_send)
  missing_columns <- setdiff(required_columns, colnames(phones_df))
  
  if (length(missing_columns) > 0) {
    stop(paste("Las siguientes columnas necesarias no existen en el archivo de entrada:", paste(missing_columns, collapse = ", ")))
  }
  
  # Agregar columnas vacías al data frame si no existen
  additional_columns <- c("status_code", "Date", "Status", "Execution", "Contact", "Url")
  for (col in additional_columns) {
    if (!col %in% colnames(phones_df)) {
      phones_df[[col]] <- NA
    }
  }
  
  # Construir la URL de la API de Twilio
  twilio_api_url <- paste0("https://studio.twilio.com/v2/Flows/", flow_id, "/Executions")
  
  # Inicializar contador de mensajes enviados en este lote
  messages_sent_in_this_batch <- 0
  
  for (i in 1:nrow(phones_df)) {
    row <- phones_df[i, ]
    to_number <- as.character(row$Number)
    
    # Crear lista con variables adicionales para enviar a Twilio
    parameters <- list()
    for (c in columns_with_info_to_send) {
      parameters[[c]] <- as.character(row[[c]])
    }
    
    # Crear payload de la solicitud
    request_payload <- list(
      To = to_number,
      From = twilio_number,
      Parameters = toJSON(parameters)
    )
    
    # Mostrar lo que se envía a Twilio
    print(request_payload)
    
    # Enviar solicitud POST
    response <- tryCatch({
      POST(twilio_api_url, authenticate(account_sid, account_token), body = request_payload, encode = "form")
    }, error = function(e) {
      message("Error en la solicitud a Twilio: ", e)
      return(NULL)
    })
    
    if (!is.null(response)) {
      response_content <- content(response, as = "text")
      response_json <- fromJSON(response_content)
      
      phones_df$status_code[i] <- status_code(response)
      
      if (status_code(response) == 200 || status_code(response) == 201) {
        phones_df$Date[i] <- as.character(Sys.time())
        phones_df$Status[i] <- response_json$status
        phones_df$Execution[i] <- response_json$sid
        phones_df$Contact[i] <- response_json$contact_channel_address
        phones_df$Url[i] <- response_json$url
      }
    }
    
    messages_sent_in_this_batch <- messages_sent_in_this_batch + 1
    
    # Dormir cada vez que terminamos un lote
    if (messages_sent_in_this_batch == batch_size) {
      print(paste("Batch finished, sleeping for", sec_between_batches))
      Sys.sleep(sec_between_batches)
      messages_sent_in_this_batch <- 0
    }
  }
  
  # Archivo de salida
  dir_path <- dirname(input_file)
  input_file_basename <- basename(input_file)
  input_file_name <- tools::file_path_sans_ext(input_file_basename)
  output_file_basename <- paste0(input_file_name, "_output.xlsx")
  output_file <- file.path(dir_path, output_file_basename)
  
  # Guardar data frame en Excel
  write.xlsx(phones_df, output_file, rowNames = FALSE)
  
  print(phones_df)
  print(paste("Result written to:", output_file))
}

