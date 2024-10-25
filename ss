<?php
include 'functions.php';
session_start();

// Verificar se o usuário está logado
if (!isset($_SESSION['loggedin']) || $_SESSION['loggedin'] !== true) {
    header("Location: login.php");
    exit;
}

// Incluir o arquivo de conexão com o banco de dados
require_once 'db.php';

// Função para processar o upload de várias imagens
function uploadImages($files) {
    $uploadDir = 'imagens/';
    $uploadMessages = [];
    $uploadedFiles = [];

    // Verificar se o diretório de upload existe, se não, criar
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Iterar sobre cada arquivo enviado
    foreach ($files['name'] as $key => $name) {
        $fileTmpName = $files['tmp_name'][$key];
        $fileSize = $files['size'][$key];
        $fileError = $files['error'][$key];
        $fileType = $files['type'][$key];

        // Verificar se o arquivo foi enviado sem erros
        if ($fileError !== UPLOAD_ERR_OK) {
            $uploadMessages[] = "Erro ao fazer upload do arquivo $name.";
            continue;
        }

        // Verificar o tipo de arquivo
        $allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
        if (!in_array($fileType, $allowedTypes)) {
            $uploadMessages[] = "Tipo de arquivo não permitido para $name. Apenas JPEG, PNG e GIF são aceitos.";
            continue;
        }

        // Verificar o tamanho do arquivo
        if ($fileSize > 2 * 1024 * 1024) {
            $uploadMessages[] = "O arquivo $name é muito grande. O tamanho máximo permitido é 2MB.";
            continue;
        }

        // Renomear o arquivo para evitar conflitos
        $uploadFile = $uploadDir . uniqid('', true) . '-' . basename($name);

        // Mover o arquivo para o diretório de upload
        if (move_uploaded_file($fileTmpName, $uploadFile)) {
            $uploadedFiles[] = $uploadFile;
        } else {
            $uploadMessages[] = "Falha ao mover o arquivo $name.";
        }
    }

    return ['files' => $uploadedFiles, 'messages' => $uploadMessages];
}

// Inicializar as variáveis
$servicos = [];
$produtos = [];
$uploadMessage = '';

// Processar o formulário
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_service']) || isset($_POST['edit_service'])) {
        $nome = $_POST['nome'] ?? '';
        $descricao = $_POST['descricao'] ?? '';
        $imagens = uploadImages($_FILES['imagens'] ?? []);
        $uploadMessage .= implode('<br>', $imagens['messages']); // Exibir mensagens de upload

        if (isset($_POST['add_service'])) {
            $sql = "INSERT INTO servicos (nome, descricao, imagem) VALUES (?, ?, ?)";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("sss", $nome, $descricao, implode(',', $imagens['files']));
            $stmt->execute();
            $stmt->close();
            $uploadMessage .= 'Serviço adicionado com sucesso!';
        } elseif (isset($_POST['edit_service'])) {
            $id = $_POST['id'] ?? null;
            if ($id !== null) {
                $sql = "UPDATE servicos SET nome = ?, descricao = ?, imagem = ? WHERE id = ?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("sssi", $nome, $descricao, implode(',', $imagens['files']), $id);
                $stmt->execute();
                $stmt->close();
                $uploadMessage .= 'Serviço editado com sucesso!';
            }
        }
    }

    // Processar produtos
    if (isset($_POST['add_product']) || isset($_POST['edit_product'])) {
        $nome = $_POST['nome'] ?? '';
        $descricao = $_POST['descricao'] ?? '';
        $preco = $_POST['preco'] ?? 0;
        $imagem = '';

        if (isset($_FILES['imagem']) && $_FILES['imagem']['error'] === UPLOAD_ERR_OK) {
            $uploadResult = uploadImage($_FILES['imagem']);
            if (strpos($uploadResult, 'Desculpe') === false) {
                $imagem = $uploadResult;
            } else {
                $uploadMessage .= $uploadResult;
            }
        }

        if (isset($_POST['add_product'])) {
            $sql = "INSERT INTO produtos (nome, descricao, preco, imagem) VALUES (?, ?, ?, ?)";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ssis", $nome, $descricao, $preco, $imagem);
            $stmt->execute();
            $stmt->close();
            $uploadMessage .= 'Produto adicionado com sucesso!';
        } elseif (isset($_POST['edit_product'])) {
            $id = $_POST['id'] ?? null;
            if ($id !== null) {
                $sql = "UPDATE produtos SET nome = ?, descricao = ?, preco = ?, imagem = ? WHERE id = ?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("ssisi", $nome, $descricao, $preco, $imagem, $id);
                $stmt->execute();
                $stmt->close();
                $uploadMessage .= 'Produto editado com sucesso!';
            }
        }
    }
}

// Excluir um serviço
if (isset($_GET['delete_id'])) {
    $id = $_GET['delete_id'] ?? null;
    if ($id !== null) {
        // Buscar o serviço para remover a imagem
        $sql = "SELECT imagem FROM servicos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $servico = $result->fetch_assoc();
        $stmt->close();
        
        // Remover a imagem do servidor
        if ($servico && file_exists($servico['imagem'])) {
            unlink($servico['imagem']);
        }

        $sql = "DELETE FROM servicos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $stmt->close();
        $uploadMessage .= 'Serviço excluído com sucesso!';
    }
}

// Excluir um produto
if (isset($_GET['delete_product_id'])) {
    $id = $_GET['delete_product_id'] ?? null;
    if ($id !== null) {
        // Buscar o produto para remover a imagem
        $sql = "SELECT imagem FROM produtos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $produto = $result->fetch_assoc();
        $stmt->close();
        
        // Remover a imagem do servidor
        if ($produto && file_exists($produto['imagem'])) {
            unlink($produto['imagem']);
        }

        $sql = "DELETE FROM produtos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $stmt->close();
        $uploadMessage .= 'Produto excluído com sucesso!';
    }
}

// Buscar todos os serviços e produtos
$servicos = getServicos($conn);
$produtos = getProdutos($conn);

// Obter dados para edição de serviço
$servicoEdit = null;
if (isset($_GET['edit_id'])) {
    $id = $_GET['edit_id'] ?? null;
    if ($id !== null) {
        $sql = "SELECT * FROM servicos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $servicoEdit = $result->fetch_assoc();
        $stmt->close();
    }
}

// Obter dados para edição de produto
$produtoEdit = null;
if (isset($_GET['edit_product_id'])) {
    $id = $_GET['edit_product_id'] ?? null;
    if ($id !== null) {
        $sql = "SELECT * FROM produtos WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        $produtoEdit = $result->fetch_assoc();
        $stmt->close();
    }
}

// Determinar a aba ativa com base no parâmetro da URL
$activeTab = $_GET['tab'] ?? 'services';
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Administração - Serviços e Produtos</title>
    <link rel="stylesheet" href="css/admin.css">
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const tabs = document.querySelectorAll('.tab');
            tabs.forEach(tab => {
                tab.addEventListener('click', function() {
                    const target = this.dataset.target;
                    document.querySelectorAll('.tab-content').forEach(content => {
                        content.classList.remove('active');
                    });
                    document.querySelector(`#${target}`).classList.add('active');
                    tabs.forEach(t => t.classList.remove('active'));
                    this.classList.add('active');
                });
            });

            // Ativar a aba correta com base na URL
            const activeTab = new URLSearchParams(window.location.search).get('tab') || 'services';
            document.querySelector(`.tab[data-target="${activeTab}"]`).click();
        });
    </script>
</head>
<body>
    <div class="container">
        <header>
            <h1>Administração - Serviços e Produtos</h1>
            <nav>
                <a href="logout.php">Logout</a>
            </nav>
        </header>
        <div class="tabs">
            <div class="tab" data-target="services">Serviços</div>
            <div class="tab" data-target="products">Produtos</div>
        </div>
        
        <div id="services" class="tab-content <?php echo $activeTab === 'services' ? 'active' : ''; ?>">
            <h2>Gerenciar Serviços</h2>
            <form method="post" enctype="multipart/form-data">
                <input type="hidden" name="id" value="<?php echo htmlspecialchars($servicoEdit['id'] ?? ''); ?>">
                <div class="form-group">
                    <label for="nome">Nome</label>
                    <input type="text" name="nome" id="nome" value="<?php echo htmlspecialchars($servicoEdit['nome'] ?? ''); ?>" required>
                </div>
                <div class="form-group">
                    <label for="descricao">Descrição</label>
                    <textarea name="descricao" id="descricao" required><?php echo htmlspecialchars($servicoEdit['descricao'] ?? ''); ?></textarea>
                </div>
                <div class="form-group">
                    <label for="imagens">Cadastrar imagens: (escolha uma ou mais imagens:)</label>
                    <input type="file" id="imagens" name="imagens[]" multiple>
                </div>
                <?php if ($servicoEdit): ?>
                    <button type="submit" name="edit_service">Salvar Alterações</button>
                <?php else: ?>
                    <button type="submit" name="add_service">Adicionar Serviço</button>
                <?php endif; ?>
                <?php if ($uploadMessage): ?>
                    <p><?php echo htmlspecialchars($uploadMessage); ?></p>
                <?php endif; ?>
            </form>
            
            <h3>Serviços Cadastrados</h3>
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Nome</th>
                        <th>Descrição</th>
                        <th>Imagem</th>
                        <th>Ações</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($servicos as $servico): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($servico['id']); ?></td>
                            <td><?php echo htmlspecialchars($servico['nome']); ?></td>
                            <td><?php echo htmlspecialchars($servico['descricao']); ?></td>
                            <td><img src="<?php echo htmlspecialchars($servico['imagem']); ?>" class="image-preview" alt="Imagem"></td>
                            <td>
                                <a href="?edit_id=<?php echo htmlspecialchars($servico['id']); ?>&tab=services">Editar</a> |
                                <a href="?delete_id=<?php echo htmlspecialchars($servico['id']); ?>&tab=services" onclick="return confirm('Tem certeza que deseja excluir este serviço?');">Excluir</a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        
        <div id="products" class="tab-content <?php echo $activeTab === 'products' ? 'active' : ''; ?>">
            <h2>Gerenciar Produtos</h2>
            <form method="post" enctype="multipart/form-data">
                <input type="hidden" name="id" value="<?php echo htmlspecialchars($produtoEdit['id'] ?? ''); ?>">
                <div class="form-group">
                    <label for="nome">Nome</label>
                    <input type="text" name="nome" id="nome" value="<?php echo htmlspecialchars($produtoEdit['nome'] ?? ''); ?>" required>
                </div>
                <div class="form-group">
                    <label for="descricao">Descrição</label>
                    <textarea name="descricao" id="descricao" required><?php echo htmlspecialchars($produtoEdit['descricao'] ?? ''); ?></textarea>
                </div>
                <div class="form-group">
                    <label for="preco">Preço</label>
                    <input type="text" name="preco" id="preco" value="<?php echo htmlspecialchars($produtoEdit['preco'] ?? ''); ?>" required>
                </div>
                <div class="form-group">
                    <label for="imagem">Imagem (Escolha um arquivo)</label>
                    <input type="file" name="imagem" id="imagem">
                </div>
                <?php if ($produtoEdit): ?>
                    <button type="submit" name="edit_product">Salvar Alterações</button>
                <?php else: ?>
                    <button type="submit" name="add_product">Adicionar Produto</button>
                <?php endif; ?>
                <?php if ($uploadMessage): ?>
                    <p><?php echo htmlspecialchars($uploadMessage); ?></p>
                <?php endif; ?>
            </form>
            
            <h3>Produtos Cadastrados</h3>
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Nome</th>
                        <th>Descrição</th>
                        <th>Preço</th>
                        <th>Imagem</th>
                        <th>Ações</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($produtos as $produto): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($produto['id']); ?></td>
                            <td><?php echo htmlspecialchars($produto['nome']); ?></td>
                            <td><?php echo htmlspecialchars($produto['descricao']); ?></td>
                            <td><?php echo htmlspecialchars($produto['preco']); ?></td>
                            <td><img src="<?php echo htmlspecialchars($produto['imagem']); ?>" class="image-preview" alt="Imagem"></td>
                            <td>
                                <a href="?edit_product_id=<?php echo htmlspecialchars($produto['id']); ?>&tab=products">Editar</a> |
                                <a href="?delete_product_id=<?php echo htmlspecialchars($produto['id']); ?>&tab=products" onclick="return confirm('Tem certeza que deseja excluir este produto?');">Excluir</a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
