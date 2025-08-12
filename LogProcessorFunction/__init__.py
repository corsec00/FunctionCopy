import logging
import azure.functions as func
import os
import tempfile
from datetime import datetime
from azure.storage.blob import BlobServiceClient
from smbclient import open_file, listdir, remove_file
from smbclient.exceptions import SMBException
import re
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential


def main(mytimer: func.TimerRequest) -> None:
    """
    Azure Function que processa arquivos de log do compartilhamento de rede
    e move arquivos filtrados para o Blob Storage usando Azure Key Vault para credenciais
    """
    utc_timestamp = datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due:
        logging.info('The timer is past due!')

    logging.info(f'Python timer trigger function executed at {utc_timestamp}')

    try:
        # Configurações obtidas das Application Settings
        key_vault_url = os.environ['KEY_VAULT_URL']
        container_name = os.environ['BLOB_CONTAINER_NAME']
        
        # Inicializar cliente do Key Vault com Managed Identity
        credential = DefaultAzureCredential()
        secret_client = SecretClient(vault_url=key_vault_url, credential=credential)
        
        # Obter credenciais do Key Vault
        smb_server = secret_client.get_secret("smb-server").value
        smb_share = secret_client.get_secret("smb-share").value
        smb_username = secret_client.get_secret("smb-username").value
        smb_password = secret_client.get_secret("smb-password").value
        storage_connection_string = secret_client.get_secret("storage-connection-string").value

        # Configurar conexão SMB
        smb_path = f"\\\\{smb_server}\\{smb_share}"

        # Configurar cliente do Blob Storage
        blob_service_client = BlobServiceClient.from_connection_string(storage_connection_string)

        # Processar arquivos
        processed_files = process_log_files(
            smb_path, smb_username, smb_password,
            blob_service_client, container_name
        )

        logging.info(f'Processamento concluído. {processed_files} arquivos processados.')

    except Exception as e:
        logging.error(f'Erro durante o processamento: {str(e)}')
        raise


def process_log_files(smb_path, username, password, blob_client, container_name):
    """
    Processa arquivos de log do compartilhamento SMB
    """
    processed_count = 0

    try:
        # Listar arquivos no compartilhamento SMB
        files = listdir(smb_path, username=username, password=password)

        for file_info in files:
            filename = file_info.name

            # Verificar se é arquivo LOG ou TXT
            if not (filename.lower().endswith('.log') or filename.lower().endswith('.txt')):
                continue

            logging.info(f'Processando arquivo: {filename}')

            try:
                # Processar arquivo individual
                if process_single_file(smb_path, filename, username, password, blob_client, container_name):
                    processed_count += 1

            except Exception as e:
                logging.error(f'Erro ao processar {filename}: {str(e)}')
                continue

    except SMBException as e:
        logging.error(f'Erro de conexão SMB: {str(e)}')
        raise

    return processed_count


def process_single_file(smb_path, filename, username, password, blob_client, container_name):
    """
    Processa um único arquivo de log
    """
    file_path = f"{smb_path}\\{filename}"

    try:
        # Ler arquivo do compartilhamento SMB
        with open_file(file_path, mode='r', username=username, password=password, encoding='utf-8') as file:
            lines = file.readlines()

        # Filtrar linhas que contenham os termos especificados
        filtered_lines = filter_log_lines(lines)

        if not filtered_lines:
            logging.info(f'Nenhuma linha relevante encontrada em {filename}')
            return False

        # Criar arquivo temporário com linhas filtradas
        with tempfile.NamedTemporaryFile(mode='w', delete=False, encoding='utf-8') as temp_file:
            temp_file.writelines(filtered_lines)
            temp_file_path = temp_file.name

        try:
            # Upload para Blob Storage
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            blob_name = f"processed_{timestamp}_{filename}"
            
            with open(temp_file_path, 'rb') as data:
                blob_client.get_blob_client(container=container_name, blob=blob_name).upload_blob(
                    data, overwrite=True
                )

            logging.info(f'Arquivo {filename} processado e enviado como {blob_name}')

            # Remover arquivo original após upload bem-sucedido
            remove_file(file_path, username=username, password=password)
            logging.info(f'Arquivo original {filename} removido')

            return True

        finally:
            # Limpar arquivo temporário
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)

    except Exception as e:
        logging.error(f'Erro ao processar arquivo {filename}: {str(e)}')
        return False


def filter_log_lines(lines):
    """
    Filtra linhas que contenham palavras-chave específicas
    """
    keywords = ['login', 'logout', 'fail']
    filtered_lines = []

    for line in lines:
        line_lower = line.lower()
        if any(keyword in line_lower for keyword in keywords):
            filtered_lines.append(line)

    return filtered_lines


def get_secret_safely(secret_client, secret_name):
    """
    Obtém um segredo do Key Vault com tratamento de erro
    """
    try:
        return secret_client.get_secret(secret_name).value
    except Exception as e:
        logging.error(f'Erro ao obter segredo {secret_name}: {str(e)}')
        raise


def validate_configuration():
    """
    Valida se todas as configurações necessárias estão presentes
    """
    required_env_vars = [
        'KEY_VAULT_URL',
        'BLOB_CONTAINER_NAME'
    ]
    
    missing_vars = []
    for var in required_env_vars:
        if not os.environ.get(var):
            missing_vars.append(var)
    
    if missing_vars:
        raise ValueError(f"Variáveis de ambiente obrigatórias não encontradas: {', '.join(missing_vars)}")
    
    return True

