# R_twilio_request
You can load the main functions from this repo
```r
source('https://raw.githubusercontent.com/jbenitesg/R_twilio_request/main/twilio_request.R')
```

## Launch of Twilio messages
```r 
# input_file: Contains the info to send to Twilio (numbers and preload data)
# batch_size: Number of launch per bacth
# sec_between_batches: Seconds sleep between batches
# columns_with_info_to_send = Vector of colnames of the data that is necesary to send your Twilio flow
launch_twilio_messages(
  account_sid = 'YOUR_ACCOUNT_SID',
  account_token = 'YOUR_ACCOUNT_TOKEN',
  flow_id = 'YOUR_FLOW_ID',
  twilio_number = 'YOUR_TWILIO_NUMBER',
  input_file = "YOUR_FILE.xlsx",
  batch_size = 20,
  sec_between_batches = 30,
  columns_with_info_to_send = c('Number', 'col1', 'col2')
)
```
## Decrypt data from Twilio
```r 
# Data:  You can load the data in any format (csv, Excel, etc.)
# encrypt_cols: Target columns from your data to decrypt
encyrpt_cols = c('var1_encrypt','var2_encrypt')
data  = data %>%
    mutate_at(
        vars(encrypt_cols),
        ~ decrypt(
        encrypted = .x,
        key = 'YOUR_ENCRYPT_KEY'
        )
    )
```
