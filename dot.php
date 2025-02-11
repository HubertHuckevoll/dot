<?php

declare(strict_types=1);

class Dot
{
    private string $projectDir;
    private string $dataDir;
    private string $frontendDir;
    private string $renderedDir;

    private string $articleDir;
    private string $pageDir;
    private string $templateDir;
    private string $articleHtmlDir;
    private string $pageHtmlDir;
    private string $indexFile;

    private string $templateSourceDir;

    public function __construct(string $projectDir)
    {
        $this->projectDir = rtrim($projectDir, '/');
        $this->dataDir = $this->projectDir . ".data/";
        $this->frontendDir = $this->projectDir . ".frontend/";
        $this->renderedDir = $this->projectDir . ".rendered/";

        $this->articleDir = $this->dataDir . "articles/";
        $this->pageDir = $this->dataDir . "pages/";
        $this->templateDir = $this->frontendDir . "html/";
        $this->articleHtmlDir = $this->renderedDir . "articles/";
        $this->pageHtmlDir = $this->renderedDir . "pages/";
        $this->indexFile = $this->renderedDir . "index.html";

        $this->templateSourceDir = __DIR__ . "/project.template/";
    }

    public function init(): void
    {
        $this->ensureDirectory($this->dataDir);
        $this->ensureDirectory($this->frontendDir);
        $this->ensureDirectory($this->renderedDir);

        $this->copyDirectory($this->templateSourceDir, $this->frontendDir);

        echo "Initialized project:\n";
        echo "  Data directory: {$this->dataDir}\n";
        echo "  Frontend directory: {$this->frontendDir}\n";
        echo "  Rendered directory: {$this->renderedDir}\n";
    }

    public function createArticle(string $name): void
    {
        $timestamp = date('Y_m_d_H_i');
        $articlePath = $this->articleDir . $timestamp . '/';
        $this->ensureDirectory($articlePath);

        $markdownFile = $articlePath . $name . '.md';
        file_put_contents($markdownFile, "# New Article\n\nContent goes here.");

        echo "Created article: $markdownFile\n";
    }

    public function createPage(string $name): void
    {
        $pagePath = $this->pageDir . $name . '/';
        $this->ensureDirectory($pagePath);

        $markdownFile = $pagePath . $name . '.md';
        file_put_contents($markdownFile, "# New Page\n\nContent goes here.");

        echo "Created page: $markdownFile\n";
    }

    public function build(): void
    {
        $this->ensureDirectory($this->renderedDir);

        // Clean up old files
        $this->clearDirectory($this->renderedDir);

        // Build articles
        $this->buildContent($this->articleDir, $this->articleHtmlDir, "article.html");

        // Build pages
        $this->buildContent($this->pageDir, $this->pageHtmlDir, "page.html");

        echo "Site built successfully at {$this->renderedDir}\n";
    }

    private function buildContent(string $sourceDir, string $outputDir, string $templateFile): void
    {
        $items = array_diff(scandir($sourceDir), ['.', '..']);
        $indexContent = "<h1>Index</h1>";

        foreach ($items as $folder) {
            $folderPath = $sourceDir . $folder . '/';
            $files = array_diff(scandir($folderPath), ['.', '..']);
            $markdownFile = $folderPath . reset($files);

            if (pathinfo($markdownFile, PATHINFO_EXTENSION) === 'md') {
                $markdownContent = file_get_contents($markdownFile);
                $htmlContent = $this->markdownToHtml($markdownContent);

                preg_match('/^# (.*?)$/m', $markdownContent, $matches);
                $headline = $matches[1] ?? 'Untitled';

                $templatePath = $this->templateDir . $templateFile;
                $outputContent = $this->renderTemplate(file_get_contents($templatePath), [
                    'headline' => $headline,
                    'content' => $htmlContent,
                ]);

                $outputFolder = $outputDir . $folder . '/';
                $this->ensureDirectory($outputFolder);

                $outputFile = $outputFolder . 'index.html';
                file_put_contents($outputFile, $outputContent);

                $indexContent .= "<a href='$outputFile'>$headline</a><br>";
            }
        }

        // Write the index file
        file_put_contents($this->indexFile, $indexContent);
    }

    private function ensureDirectory(string $path): void
    {
        if (!is_dir($path)) {
            mkdir($path, 0777, true);
        }
    }

    private function copyDirectory(string $src, string $dest): void
    {
        $this->ensureDirectory($dest);
        foreach (scandir($src) as $item) {
            if ($item === '.' || $item === '..') {
                continue;
            }

            $srcPath = $src . $item;
            $destPath = $dest . $item;

            if (is_dir($srcPath)) {
                $this->copyDirectory($srcPath . '/', $destPath . '/');
            } else {
                copy($srcPath, $destPath);
            }
        }
    }

    private function clearDirectory(string $path): void
    {
        foreach (glob($path . '*') as $file) {
            if (is_dir($file)) {
                $this->clearDirectory($file . '/');
                rmdir($file);
            } else {
                unlink($file);
            }
        }
    }

    private function renderTemplate(string $template, array $placeholders): string
    {
        foreach ($placeholders as $key => $value) {
            $template = str_replace("{{" . strtoupper($key) . "}}", $value, $template);
        }
        return $template;
    }

    private function markdownToHtml(string $markdown): string
    {
        $html = htmlspecialchars($markdown);
        $html = preg_replace('/\*\*(.*?)\*\*/', '<strong>$1</strong>', $html);
        $html = preg_replace('/\*(.*?)\*/', '<em>$1</em>', $html);
        $html = preg_replace('/^# (.*?)$/m', '<h1>$1</h1>', $html);
        $html = preg_replace('/^## (.*?)$/m', '<h2>$1</h2>', $html);
        $html = preg_replace('/^### (.*?)$/m', '<h3>$1</h3>', $html);
        $html = preg_replace('/\n/', '<br>', $html);
        return $html;
    }
}

// CLI Execution
if ($argc < 2) {
    echo "Usage: php dot.php <command> <project_dir> [name]\n";
    exit(1);
}

$command = $argv[1];
$projectDir = $argv[2] ?? '';
$name = $argv[3] ?? '';

$generator = new Dot($projectDir);

switch ($command) {
    case 'init':
        $generator->init();
        break;
    case 'article':
        if ($name) {
            $generator->createArticle($name);
        } else {
            echo "Error: Missing article name.\n";
        }
        break;
    case 'page':
        if ($name) {
            $generator->createPage($name);
        } else {
            echo "Error: Missing page name.\n";
        }
        break;
    case 'build':
        $generator->build();
        break;
    default:
        echo "Unknown command: $command\n";
        break;
}
