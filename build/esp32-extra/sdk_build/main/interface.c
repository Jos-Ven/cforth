// Interfaces between ESP32/FreeRTOS and Forth

typedef int cell;

#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"

#include "esp_wifi_types.h"

#include "esp_event_loop.h"
#include "esp_log.h"
#include "esp_event.h"
#include "nvs_flash.h"

#include "lwip/err.h"
#include "lwip/sys.h"
#include "lwip/netdb.h"

#include "driver/uart.h"

extern void forth(void);

// This is the routine that is run by main_task() from cpu_start.c,
// i.e. the "call in" from FreeRTOS to Forth.
void app_main(void)
{
    nvs_flash_init();
    forth();
}

// The following routines are used by Forth to invoke functions
// defined by the SDK.  The call signatures should be based on
// simple data types, typically "int" which is the same as Forth's
// "cell" on this processor.  Doing so eliminates include dependencies
// between Forth and the SDK, i.e. we don't need to include forth.h
// herein, and we don't need to include lots of SDK .h files in the
// Forth tree.

// init_uart() sets up UART0 for the Forth console, so key and emit
// can use uart_read_bytes() and uart_write_bytes().  The reason we do
// that instead of just calling getchar() and putchar() is because we
// want a non-blocking key?, and there is no easy way to do so with
// getchar().

#define BUF_SIZE (1024)
void init_uart(void)
{
    int uart_num = UART_NUM_0;

    uart_config_t uart_config = {
       .baud_rate = 115200,
       .data_bits = UART_DATA_8_BITS,
       .parity = UART_PARITY_DISABLE,
       .stop_bits = UART_STOP_BITS_1,
       .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
       .rx_flow_ctrl_thresh = 122,
    };
    uart_param_config(uart_num, &uart_config);

    // No need to set the pins as the defaults are correct for UART0

    // Install driver with a receive buffer but no transmit buffer
    // and no event queue.
    uart_driver_install(uart_num, BUF_SIZE * 2, 0, 0, NULL, 0);
}

cell my_uart_param_config(int uart_num, int baud, int bits, int par, int stop, int flow)
{
    uart_config_t uart_config = {
       .baud_rate = baud,
       .data_bits = bits-5,
       .parity = par,
       .stop_bits = stop,
       .flow_ctrl = flow,
       .rx_flow_ctrl_thresh = 122,
    };
   return uart_param_config(uart_num, &uart_config);
}

// Routines for the ccalls[] table in textend.c.  Add new ones
// as necessary.

void ms(int msecs)
{
    vTaskDelay(msecs/ portTICK_PERIOD_MS);
}

#include "driver/i2c.h"

#define I2C_NUM 1
#define ACK_CHECK 1
#define ACK_VAL 0
#define NACK_VAL 1

// void i2c_setup(cell sda, cell scl)
cell i2c_open(uint8_t sda, uint8_t scl)
{
    int i2c_master_port = 1;
    i2c_config_t conf;
    conf.mode = I2C_MODE_MASTER;
    conf.sda_io_num = sda;
    conf.sda_pullup_en = GPIO_PULLUP_ENABLE;
    conf.scl_io_num = scl;
    conf.scl_pullup_en = GPIO_PULLUP_ENABLE;
    conf.master.clk_speed = 100000;
    i2c_param_config(i2c_master_port, &conf);
    return i2c_driver_install(i2c_master_port, conf.mode,
                       0, 0, 0  // No Rx buf, No Tx buf, no intr flags
                       );
}
void i2c_close()
{
    i2c_driver_delete(1);
}

#define I2C_FINISH \
    i2c_master_stop(cmd); \
    esp_err_t ret = i2c_master_cmd_begin(I2C_NUM, cmd, 1000 / portTICK_RATE_MS); \
    i2c_cmd_link_delete(cmd);

int i2c_write_read(uint8_t stop, uint8_t slave, uint8_t rsize, uint8_t *rbuf, uint8_t wsize, uint8_t *wbuf)
{
    if (rsize == 0 && wsize == 0) {
        return ESP_OK;
    }

    i2c_cmd_handle_t cmd;
    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    if (wsize) {
	i2c_master_write_byte(cmd, ( slave << 1 ) | I2C_MASTER_WRITE, ACK_CHECK);
	i2c_master_write(cmd, wbuf, wsize, ACK_CHECK);
	if (!rsize) {
    i2c_master_stop(cmd); \
    esp_err_t ret = i2c_master_cmd_begin(I2C_NUM, cmd, 1000 / portTICK_RATE_MS); \
    i2c_cmd_link_delete(cmd);
//	    I2C_FINISH;
	    return ret;
	}
	if (stop) { // rsize is nonzero
    i2c_master_stop(cmd); \
    esp_err_t ret = i2c_master_cmd_begin(I2C_NUM, cmd, 1000 / portTICK_RATE_MS); \
    i2c_cmd_link_delete(cmd);
//	    I2C_FINISH;
	    if (ret)
		return -1;
	    cmd = i2c_cmd_link_create();
	    i2c_master_start(cmd);
	} else {
	    i2c_master_start(cmd);
	}
	i2c_master_write_byte(cmd, ( slave << 1 ) | I2C_MASTER_READ, ACK_CHECK);
    } else {
	// rsize must be nonzero because of the initial check at the top
	i2c_master_write_byte(cmd, ( slave << 1 ) | I2C_MASTER_READ, ACK_CHECK);
    }

    if (rsize > 1) {
        i2c_master_read(cmd, rbuf, rsize - 1, ACK_VAL);
    }
    i2c_master_read_byte(cmd, rbuf + rsize - 1, NACK_VAL);

    I2C_FINISH;
    return ret;
}

cell i2c_rb(int stop, int slave, int reg)
{
    uint8_t rval[1];
    uint8_t regb[1] = { reg };
    if (i2c_write_read(stop, slave, 1, rval, 1, regb))
	return -1;
    return rval[0];
}

cell i2c_be_rw(cell stop, cell slave, cell reg)
{
    uint8_t rval[2];
    uint8_t regb[1] = { reg };
    if (i2c_write_read(stop, slave, 2, rval, 1, regb))
	return -1;
    return (rval[0]<<8) + rval[1];
}

cell i2c_le_rw(cell stop, cell slave, cell reg)
{
    uint8_t rval[2];
    uint8_t regb[1] = { reg };
    if (i2c_write_read(stop, slave, 2, rval, 1, regb))
	return -1;
    return (rval[1]<<8) + rval[0];
}

cell i2c_wb(cell slave, cell reg, cell value)
{
    uint8_t buf[2] = {reg, value};
    return i2c_write_read(0, slave, 0, 0, 2, buf);
}

cell i2c_be_ww(cell slave, cell reg, cell value)
{
    uint8_t buf[3] = {reg, value >> 8, value & 0xff};
    return i2c_write_read(0, slave, 0, 0, 3, buf);
}

cell i2c_le_ww(cell slave, cell reg, cell value)
{
    uint8_t buf[3] = {reg, value & 0xff, value >> 8};
    return i2c_write_read(0, slave, 0, 0, 3, buf);
}

#include "driver/gpio.h"
cell gpio_pin_fetch(cell gpio_num)
{
    return gpio_get_level(gpio_num) ? -1 : 0;
}

void gpio_pin_store(cell gpio_num, cell level)
{
    gpio_set_level(gpio_num, level);
}

void gpio_toggle(cell gpio_num)
{
    int level = gpio_get_level(gpio_num);
    gpio_set_level(gpio_num, !level);
}

void gpio_is_output(cell gpio_num)
{
    gpio_set_direction(gpio_num, GPIO_MODE_OUTPUT);
}

void gpio_is_output_od(cell gpio_num)
{
    gpio_set_direction(gpio_num, GPIO_MODE_OUTPUT_OD);
}

void gpio_is_input(cell gpio_num)
{
    gpio_set_pull_mode(gpio_num, GPIO_FLOATING);
    gpio_set_direction(gpio_num, GPIO_MODE_INPUT);
}

void gpio_is_input_pu(cell gpio_num)
{
    gpio_set_pull_mode(gpio_num, GPIO_PULLUP_ONLY);
    gpio_set_direction(gpio_num, GPIO_MODE_INPUT);
}

void gpio_is_input_pd(cell gpio_num)
{
    gpio_set_pull_mode(gpio_num, GPIO_PULLDOWN_ONLY);
    gpio_set_direction(gpio_num, GPIO_MODE_INPUT);
}

// For compatibility with ESP8266 interface
// 1 constant gpio-input
// 2 constant gpio-output
// 6 constant gpio-opendrain
void gpio_mode(cell gpio_num, cell direction, cell pull)
{
    gpio_set_direction(gpio_num, direction);
    if (pull) {
        gpio_pullup_en(gpio_num);
    } else {
        gpio_pullup_dis(gpio_num);
    }
}

/* FreeRTOS event group to signal when we are connected & ready to make a request */
static EventGroupHandle_t wifi_event_group;

/* The event group allows multiple bits for each event,
   but we only care about one event - are we connected
   to the AP with an IP? */
const int CONNECTED_BIT = BIT0;

static esp_err_t wifi_event_handler(void *ctx, system_event_t *event)
{
    switch(event->event_id) {
    case SYSTEM_EVENT_STA_START:
        esp_wifi_connect();
        break;
    case SYSTEM_EVENT_STA_GOT_IP:
        xEventGroupSetBits(wifi_event_group, CONNECTED_BIT);
        break;
    case SYSTEM_EVENT_STA_DISCONNECTED:
        /* This is a workaround as ESP32 WiFi libs don't currently
           auto-reassociate. */
        esp_wifi_connect();
        xEventGroupClearBits(wifi_event_group, CONNECTED_BIT);
        break;
    default:
        break;
    }
    return ESP_OK;
}

cell wifi_open(cell timeout, char *password, char *ssid)
{
    tcpip_adapter_init();
    wifi_event_group = xEventGroupCreate();
    if (esp_event_loop_init(wifi_event_handler, NULL)) return -1;
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    if (esp_wifi_init(&cfg) ) return -2;
    if (esp_wifi_set_storage(WIFI_STORAGE_RAM)) return -3;
    wifi_config_t wifi_config = { };
    strncpy((char *)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid));
    strncpy((char *)wifi_config.sta.password, password, sizeof(wifi_config.sta.password));
    if(esp_wifi_set_mode(WIFI_MODE_STA)) return -4;
    if(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config)) return -5;
    if(esp_wifi_start()) return -6;
    if (xEventGroupWaitBits(wifi_event_group, CONNECTED_BIT, false, true, timeout) != CONNECTED_BIT) return -7;
    return 0;
}

static esp_err_t esp_now_event_handler(void *ctx, system_event_t *event)
{
    switch(event->event_id) {
    case SYSTEM_EVENT_STA_START:
//         printf ("%s \n", "WiFi for ESP-NOW started");
        break;
    default:
        break;
    }
    return ESP_OK;
}

//  esp_now_open and wifi_open can not both be used at the same time!

cell esp_now_open(int channel)
{
    tcpip_adapter_init();
    if ( esp_event_loop_init(esp_now_event_handler, NULL)) return -1;
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);
    esp_wifi_set_storage(WIFI_STORAGE_RAM);
    if ( esp_wifi_set_mode(WIFI_MODE_STA) ) return -2;
    if ( esp_wifi_start()) return -3;
    if ( esp_wifi_set_channel(channel,WIFI_SECOND_CHAN_NONE)) return -4;
    return 0;
}

cell get_wifi_mode(void)
{
    wifi_mode_t mode;
    esp_wifi_get_mode(&mode);
    return mode;
}

static DRAM_ATTR portMUX_TYPE global_int_mux = portMUX_INITIALIZER_UNLOCKED;

void IRAM_ATTR interrupt_disable()
{
    if (xPortInIsrContext()) {
        portENTER_CRITICAL_ISR(&global_int_mux);
    } else {
        portENTER_CRITICAL(&global_int_mux);
    }
}

void IRAM_ATTR interrupt_restore()
{
    if (xPortInIsrContext()) {
        portEXIT_CRITICAL_ISR(&global_int_mux);
    } else {
        portEXIT_CRITICAL(&global_int_mux);
    }
}

void set_log_level(char *component, int level)
{
    esp_log_level_set(component, level);
}

int client_socket(char *host, char *portstr, cell protocol)
{
    struct addrinfo hints, *res, *res0;
    int error;
    int s;
    const char *cause = NULL;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = protocol;

    error = getaddrinfo(host, portstr, &hints, &res0);
    if (error) {
        perror("getaddrinfo");
        return -1;
    }
    s = -1;
    for (res = res0; res; res = res->ai_next) {
        s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        if (s < 0) {
            cause = "socket";
            continue;
        }
        if (connect(s, res->ai_addr, res->ai_addrlen) < 0) {
            cause = "connect";
            close(s);
            s = -1;
            continue;
        }
        break;  /* okay we got one */
    }
    freeaddrinfo(res0);
    if (s < 0) {
        printf("%s", cause);
        return -2;
    }

    return s;
}

cell udp_client(char *host, char *portstr)
{
    return client_socket(host, portstr, SOCK_DGRAM);
}

int stream_connect(char *host, char *portstr, int timeout_msecs)
{
    int s = client_socket(host, portstr, SOCK_STREAM);
    int error;
    if (s < 0) {
        return s;
    }

    struct timeval recv_timeout;
    recv_timeout.tv_sec = timeout_msecs / 1000;
    recv_timeout.tv_usec = (timeout_msecs % 1000) * 1000;

    error = setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &recv_timeout, sizeof(recv_timeout));
    if (error) {
        perror("unable to set receive timeout.");
        return -3;
    }
    return s;
}

cell start_server(cell port)
{
    struct addrinfo hints, *res, *p;
    char portstr[10];
    snprintf(portstr, 10, "%d", port);
    int listenfd = -1;

    // getaddrinfo for host
    memset (&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;
    if (getaddrinfo( NULL, portstr, &hints, &res) != 0)
	return -1;
    // socket and bind
    for (p = res; p!=NULL; p=p->ai_next)
    {
        listenfd = socket (p->ai_family, p->ai_socktype, 0);
        if (listenfd == -1) continue;

        if (bind(listenfd, p->ai_addr, p->ai_addrlen) == 0) break;
    }
    if (p==NULL)
	return -2;

    freeaddrinfo(res);

    // listen for incoming connections
    if ( listen (listenfd, 1000000) != 0 ) {
	close(listenfd);
	return -3;
    }
    return listenfd;
}

cell my_select(cell maxfdp1, void *reads, void *writes, void *excepts, cell msecs)
{
    struct timeval to = { .tv_sec = msecs/1000, .tv_usec = (msecs%1000)*1000 };
    return (cell)lwip_select((int)maxfdp1, (fd_set *)reads, (fd_set *)writes, (fd_set *)excepts, &to);
}

cell dhcpc_status(void)
{
    tcpip_adapter_dhcp_status_t status;
    tcpip_adapter_dhcpc_get_status(TCPIP_ADAPTER_IF_STA, &status);
    return status;
}

void ip_info(void *buf)
{
    tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_STA, (tcpip_adapter_ip_info_t *)buf);
}

cell my_lwip_write(cell handle, cell len, void *adr)
{
    return (cell)lwip_write_r((int)handle, adr, (size_t)len);
}

cell my_lwip_read(cell handle, cell len, void *adr)
{
    return (cell)lwip_read_r((int)handle, adr, (size_t)len);
}

#include <errno.h>
#include <sys/fcntl.h>
#include "esp_vfs.h"
#include "esp_vfs_fat.h"
#include "esp_log.h"
#include "spiffs_vfs.h"
#include "driver/spi_master.h"
#include "driver/spi_slave.h"



void init_filesystem(void)
{
    esp_log_level_set("[SPIFFS]", 0);
    vfs_spiffs_register();
}

void my_spiffs_unmount(void)
{
    spiffs_unmount(0);
}

void *open_dir(char *name)
{
    return opendir(name);
}


void *next_file(void *dir)
{
    struct dirent *ent;

    while ((ent = readdir((DIR *)dir)) != NULL) {
	if (ent->d_type == DT_REG) {
	    return ent;
	}
    }
    return NULL;
}

char *dirent_name(void *ent)
{
    return ((struct dirent *)ent)->d_name;
}


cell dirent_size(void *ent, char *name)
{
    struct stat statbuf;
     if (stat(name, &statbuf)) {
	return -1;
    }
    return statbuf.st_size;
}

cell rename_file(char *new, char *old)
{
    return  rename(old, new);
}

cell fs_avail(void)
{
  u32_t total, used;
  spiffs_fs_stat(&total, &used);
  return (cell)(total - used);
}

cell delete_file(char *name)
{
    return remove(name);
}

void restart(void)
{
    esp_restart();
}

#include <rom/ets_sys.h>

void IRAM_ATTR us(uint32_t us)
{
    ets_delay_us(us);
}

int IRAM_ATTR get_system_time(struct timeval *tp)
{
struct timeval tv = { .tv_sec = 0, .tv_usec = 0 };
        gettimeofday(&tv, NULL);
        *tp = tv;
        return 0;
}

void set_system_time(cell sec)
{
struct timeval tv = { .tv_sec =  sec };
         settimeofday(&tv,NULL);
}

esp_err_t spi_bus_init(int mosi, int miso, int sclk, int dma)
{
    spi_bus_config_t buscfg={
        .mosi_io_num=mosi,
        .miso_io_num=miso,
        .sclk_io_num=sclk,
        .quadwp_io_num=-1,
        .quadhd_io_num=-1
    };
  return spi_bus_initialize(VSPI_HOST, &buscfg, dma);
}

spi_device_handle_t spi_bus_setup(int clkspeed, int SpiMode, int qsize) {
        spi_device_handle_t handle;
        spi_device_interface_config_t devcfg={
        .command_bits=0,
        .address_bits=0,
        .dummy_bits=0,
        .clock_speed_hz=clkspeed,
//        .duty_cycle_pos=128,        // 50% duty cycle
        .mode=SpiMode,
        .spics_io_num=-1,
        .queue_size=qsize,
//        .cs_ena_posttrans=3,        // Keep the CS low 3 cycles after transaction,
    };
  spi_bus_add_device(VSPI_HOST, &devcfg, &handle);
  return handle;
}

//Send data to the LCD. Uses spi_device_transmit, which waits until the transfer is complete.
int32_t  spi_master_data(spi_device_handle_t spi, uint8_t *receive, uint8_t *send, uint16_t size)  {
	spi_transaction_t trans_t;
	trans_t.rx_buffer = receive;
	trans_t.tx_buffer = send;
	trans_t.rxlength = 0;
	trans_t.length = 8 * size;
	trans_t.flags = 0;
	trans_t.cmd = 0;
	trans_t.addr = 0;
	trans_t.user = NULL;
	return spi_device_transmit(spi, &trans_t);
}

int32_t spi_bus_init_slave( int mosi, int miso, int sclk, int spics, int mode, int dma, int qsize)  {
    spi_bus_config_t buscfg={
        .mosi_io_num=mosi,
        .miso_io_num=miso,
        .sclk_io_num=sclk
    };

    spi_slave_interface_config_t slvcfg={
        .mode=mode,
        .spics_io_num=spics=spics,
        .queue_size=qsize,
        .flags=0,
    };

       return spi_slave_initialize(VSPI_HOST, &buscfg, &slvcfg, dma);
}

int32_t spi_slave_data(int ticks_to_wait, int size, void *sendbuf, void *recvbuf)  {
   spi_slave_transaction_t t;
        //Set up a transaction of 128 bytes to send/receive
        t.length=size*8;
        t.tx_buffer=sendbuf;
        t.rx_buffer=recvbuf;
       return spi_slave_transmit(VSPI_HOST, &t, ticks_to_wait);
}

#include "sdmmc_cmd.h"

static const char *TAG = "SDcard: ";

cell sd_mount(int sd_speed, int format_option, int sd_mosi, int sd_miso, int sd_clk, int sd_cs )
{
// Pin mapping when using SPI mode.
    sdmmc_host_t host = SDSPI_HOST_DEFAULT();
    host.max_freq_khz = sd_speed;  // 20000 is too high
    sdspi_slot_config_t slot_config = SDSPI_SLOT_CONFIG_DEFAULT();
    slot_config.gpio_miso = sd_miso;
    slot_config.gpio_mosi = sd_mosi;
    slot_config.gpio_sck  = sd_clk;
    slot_config.gpio_cs   = sd_cs;
    // This initializes the slot without card detect (CD) and write protect (WP) signals.
    // Modify slot_config.gpio_cd and slot_config.gpio_wp if your board has these signals.

    // Options for mounting the filesystem.
    // If format_if_mount_failed is set to true, SD card will be partitioned and
    // formatted in case when mounting fails.
    esp_vfs_fat_sdmmc_mount_config_t mount_config = {
        .format_if_mount_failed = format_option,
        .max_files = 5,
        .allocation_unit_size = 16 * 1024
    };

    // Use settings defined above to initialize SD card and mount FAT filesystem.
    // Note: esp_vfs_fat_sdmmc_mount is an all-in-one convenience function.
    // Please check its source code and implement error recovery when developing
    // production applications.
    sdmmc_card_t* card;
    esp_err_t ret = esp_vfs_fat_sdmmc_mount("/sdcard", &host, &slot_config, &mount_config, &card);

    if (ret != ESP_OK) {
        if (ret == ESP_FAIL) {
            ESP_LOGE(TAG, "Failed to mount filesystem. "
                "If you want the card to be formatted, set format_if_mount_failed = true.");
        } else {
            ESP_LOGE(TAG, "Failed to initialize the card (%s). "
                " ", esp_err_to_name(ret));
        }
        return ret;
    }
    // Card has been initialized, print its properties
    printf( " \n" );
    sdmmc_card_print_info(stdout, card);
    return ret;
}

void sd_unmount()
{
      esp_vfs_fat_sdmmc_unmount();
      ESP_LOGI(TAG, "Card unmounted");
}

cell mysetvbuf(int size, void *buf, int method, FILE* fp)
{
      esp_err_t ret = setvbuf(fp, buf, method, size);
      return ret;
}
