# Makefile для сайта театральной группы КонТекст

.PHONY: help dev build clean serve cms proxy deploy install check

# Переменные
HUGO_ENV ?= development
PORT ?= 1313
CMS_PORT ?= 8082

# Цвета для вывода
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

help: ## Показать справку по командам
	@echo "$(GREEN)Доступные команды:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

install: ## Установить зависимости
	@echo "$(GREEN)Установка зависимостей...$(NC)"
	@if ! command -v hugo >/dev/null 2>&1; then \
		echo "$(RED)Ошибка: Hugo не установлен. Установите Hugo: https://gohugo.io/installation/$(NC)"; \
		exit 1; \
	fi
	@if ! command -v npm >/dev/null 2>&1; then \
		echo "$(YELLOW)npm не найден, устанавливаем только Hugo зависимости$(NC)"; \
	else \
		echo "$(GREEN)Установка netlify-cms-proxy-server...$(NC)"; \
		npm install -g netlify-cms-proxy-server; \
	fi
	@echo "$(GREEN)Инициализация Hugo модулей...$(NC)"
	hugo mod init github.com/kontext-theater/website || true
	@echo "$(GREEN)Зависимости установлены!$(NC)"

dev: ## Запустить сервер разработки
	@echo "$(GREEN)Запуск Hugo сервера разработки на порту $(PORT)...$(NC)"
	hugo server -D --port $(PORT) --bind 0.0.0.0 --baseURL http://localhost:$(PORT)

serve: dev ## Алиас для dev

build: ## Собрать сайт для продакшена
	@echo "$(GREEN)Сборка сайта для продакшена...$(NC)"
	HUGO_ENV=production hugo --gc --minify

build-dev: ## Собрать сайт для разработки
	@echo "$(GREEN)Сборка сайта для разработки...$(NC)"
	hugo --buildDrafts --buildFuture

clean: ## Очистить сгенерированные файлы
	@echo "$(GREEN)Очистка...$(NC)"
	rm -rf public/
	rm -rf resources/_gen/
	@echo "$(GREEN)Очистка завершена!$(NC)"

cms: ## Запустить Netlify CMS локально (требует proxy)
	@echo "$(GREEN)Открытие Netlify CMS...$(NC)"
	@echo "$(YELLOW)Убедитесь, что запущен proxy-сервер (make proxy)$(NC)"
	@echo "$(YELLOW)CMS доступен по адресу: http://localhost:$(PORT)/admin/$(NC)"
	@if command -v open >/dev/null 2>&1; then \
		open "http://localhost:$(PORT)/admin/"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "http://localhost:$(PORT)/admin/"; \
	fi

proxy: ## Запустить Netlify CMS proxy-сервер
	@echo "$(GREEN)Запуск Netlify CMS proxy-сервера на порту $(CMS_PORT)...$(NC)"
	@if ! command -v netlify-cms-proxy-server >/dev/null 2>&1; then \
		echo "$(RED)Ошибка: netlify-cms-proxy-server не установлен$(NC)"; \
		echo "$(YELLOW)Выполните: make install$(NC)"; \
		exit 1; \
	fi
	netlify-cms-proxy-server --port $(CMS_PORT)

dev-full: ## Запустить полную среду разработки (Hugo + CMS proxy)
	@echo "$(GREEN)Запуск полной среды разработки...$(NC)"
	@echo "$(YELLOW)Запуск proxy-сервера в фоне...$(NC)"
	netlify-cms-proxy-server --port $(CMS_PORT) & \
	echo $$! > .proxy.pid; \
	sleep 2; \
	echo "$(YELLOW)Запуск Hugo сервера...$(NC)"; \
	hugo server -D --port $(PORT) --bind 0.0.0.0 --baseURL http://localhost:$(PORT) || (kill `cat .proxy.pid` 2>/dev/null; rm -f .proxy.pid)

stop: ## Остановить все процессы разработки
	@echo "$(GREEN)Остановка процессов...$(NC)"
	@if [ -f .proxy.pid ]; then \
		kill `cat .proxy.pid` 2>/dev/null || true; \
		rm -f .proxy.pid; \
		echo "$(GREEN)Proxy-сервер остановлен$(NC)"; \
	fi
	@echo "$(YELLOW)Поиск и остановка Hugo процессов...$(NC)"
	@ps aux | grep -E 'hugo server|hugo serve' | grep -v grep | awk '{print $$2}' | xargs -r kill -9 2>/dev/null || true
	@killall hugo 2>/dev/null || true
	@echo "$(GREEN)Все процессы остановлены$(NC)"

check: ## Проверить конфигурацию и контент
	@echo "$(GREEN)Проверка конфигурации Hugo...$(NC)"
	hugo config
	@echo "\n$(GREEN)Проверка контента...$(NC)"
	hugo list all
	@echo "\n$(GREEN)Проверка на ошибки...$(NC)"
	hugo --printI18nWarnings --printPathWarnings

netlify-setup: ## Показать инструкции по настройке Netlify Identity
	@echo "$(GREEN)=== Настройка Netlify Identity ===$(NC)"
	@echo "$(YELLOW)1. Откройте https://app.netlify.com/$(NC)"
	@echo "$(YELLOW)2. Выберите сайт kontext-site$(NC)"
	@echo "$(YELLOW)3. Перейдите в Site settings → Identity$(NC)"
	@echo "$(YELLOW)4. Нажмите 'Enable Identity'$(NC)"
	@echo "$(YELLOW)5. В Services включите 'Git Gateway'$(NC)"
	@echo "$(YELLOW)6. В Users добавьте пользователя (Invite users)$(NC)"
	@echo ""
	@echo "$(GREEN)=== Дополнительные настройки ===$(NC)"
	@echo "$(YELLOW)7. В Settings and usage настройте:$(NC)"
	@echo "   - Registration preferences: Invite only (рекомендуется)"
	@echo "   - External providers: GitHub, Google (опционально)"
	@echo "   - Emails: настройте шаблоны для восстановления пароля"
	@echo ""
	@echo "$(GREEN)=== Настройка ролей ===$(NC)"
	@echo "$(YELLOW)8. В Settings and usage → Roles добавьте роли:$(NC)"
	@echo "   - admin: полный доступ к CMS"
	@echo "   - editor: редактирование контента"
	@echo "   - author: создание постов"
	@echo ""
	@echo "$(GREEN)После настройки админ панель будет доступна по адресу:$(NC)"
	@echo "$(GREEN)https://kontext-site.netlify.app/admin/$(NC)"

netlify-roles: ## Показать информацию о ролях в Netlify CMS
	@echo "$(GREEN)=== Роли в Netlify CMS ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Что такое роли:$(NC)"
	@echo "Роли позволяют ограничить доступ пользователей к разным частям CMS"
	@echo ""
	@echo "$(YELLOW)Рекомендуемые роли для театра:$(NC)"
	@echo "$(GREEN)admin$(NC) - полный доступ ко всему контенту и настройкам"
	@echo "$(GREEN)editor$(NC) - редактирование спектаклей, событий, страниц"
	@echo "$(GREEN)author$(NC) - создание и редактирование только своих материалов"
	@echo "$(GREEN)moderator$(NC) - модерация контента перед публикацией"
	@echo ""
	@echo "$(YELLOW)Как назначить роль пользователю:$(NC)"
	@echo "1. В Netlify Dashboard → Identity → Users"
	@echo "2. Нажмите на пользователя"
	@echo "3. В поле User metadata добавьте:"
	@echo "   {\"roles\": [\"admin\"]}"
	@echo ""
	@echo "$(YELLOW)Настройка ролей в CMS (config.yml):$(NC)"
	@echo "Роли можно настроить для ограничения доступа к коллекциям"

netlify-troubleshoot: ## Диагностика проблем с Netlify Identity
	@echo "$(GREEN)=== Диагностика Netlify Identity ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Проблема: Ошибка 'Email not confirmed'$(NC)"
	@echo "$(GREEN)Решения:$(NC)"
	@echo "1. Откройте ссылку из приглашения в email"
	@echo "2. НА СТРАНИЦЕ ПРИГЛАШЕНИЯ СОЗДАЙТЕ СВОЙ ПАРОЛЬ"
	@echo "3. Завершите процесс подтверждения email"
	@echo "4. Войдите в CMS с вашим email и созданным паролем"
	@echo "$(RED)ВАЖНО: Приглашение НЕ содержит готовый пароль!$(NC)"
	@echo ""
	@echo "$(YELLOW)Проблема: Кнопка сброса пароля не работает$(NC)"
	@echo "$(GREEN)Решения:$(NC)"
	@echo "1. Проверьте настройки Email в Identity → Settings"
	@echo "2. Убедитесь, что включены email-уведомления"
	@echo "3. Проверьте папку спам в почте"
	@echo "4. Попробуйте переслать приглашение пользователю"
	@echo ""
	@echo "$(YELLOW)Проблема: Пользователь не может войти$(NC)"
	@echo "$(GREEN)Решения:$(NC)"
	@echo "1. Убедитесь, что Git Gateway включен"
	@echo "2. Проверьте статус пользователя (не заблокирован ли)"
	@echo "3. Очистите кэш браузера"
	@echo "4. Попробуйте в режиме инкогнито"
	@echo ""
	@echo "$(YELLOW)Проблема: CMS не загружается$(NC)"
	@echo "$(GREEN)Решения:$(NC)"
	@echo "1. Проверьте настройки CSP в netlify.toml"
	@echo "2. Убедитесь, что backend настроен на git-gateway"
	@echo "3. Проверьте консоль браузера на ошибки"

lint: ## Проверить качество контента
	@echo "$(GREEN)Проверка качества контента...$(NC)"
	@find content -name "*.md" -exec grep -l "TODO\|FIXME\|XXX" {} \; | while read file; do \
		echo "$(YELLOW)В файле $$file найдены TODO/FIXME$(NC)"; \
	done
	@echo "$(GREEN)Проверка завершена$(NC)"

stats: ## Показать статистику сайта
	@echo "$(GREEN)Статистика сайта:$(NC)"
	@echo "Страницы контента:"
	@find content -name "*.md" | wc -l | xargs echo "  Всего файлов markdown:"
	@find content/ru -name "*.md" | wc -l | xargs echo "  Русский:"
	@find content/de -name "*.md" | wc -l | xargs echo "  Немецкий:"
	@find content/en -name "*.md" | wc -l | xargs echo "  Английский:"
	@echo "Изображения:"
	@find static/images -type f 2>/dev/null | wc -l | xargs echo "  Всего изображений:"
	@du -sh static/images 2>/dev/null | cut -f1 | xargs echo "  Размер папки изображений:"

deploy-check: ## Проверить готовность к деплою
	@echo "$(GREEN)Проверка готовности к деплою...$(NC)"
	@if [ ! -f netlify.toml ]; then \
		echo "$(RED)Ошибка: netlify.toml не найден$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f static/admin/config.yml ]; then \
		echo "$(RED)Ошибка: конфигурация Netlify CMS не найдена$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Сборка для проверки...$(NC)"
	@HUGO_ENV=production hugo --gc --minify
	@echo "$(GREEN)✓ Сайт готов к деплою!$(NC)"
	@echo "$(YELLOW)Размер собранного сайта:$(NC)"
	@du -sh public/

new-play: ## Создать новый спектакль (make new-play TITLE="Название" LANG=ru)
	@if [ -z "$(TITLE)" ]; then \
		echo "$(RED)Ошибка: укажите название спектакля$(NC)"; \
		echo "$(YELLOW)Пример: make new-play TITLE=\"Гамлет\" LANG=ru$(NC)"; \
		exit 1; \
	fi
	@LANG=${LANG:-ru}; \
	hugo new content/$${LANG}/plays/$(shell echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g').md
	@echo "$(GREEN)Создан новый спектакль: $(TITLE)$(NC)"

new-event: ## Создать новое событие (make new-event TITLE="Название" LANG=ru)
	@if [ -z "$(TITLE)" ]; then \
		echo "$(RED)Ошибка: укажите название события$(NC)"; \
		echo "$(YELLOW)Пример: make new-event TITLE=\"Показ Гамлета\" LANG=ru$(NC)"; \
		exit 1; \
	fi
	@LANG=${LANG:-ru}; \
	hugo new content/$${LANG}/events/$(shell echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g').md
	@echo "$(GREEN)Создано новое событие: $(TITLE)$(NC)"

backup: ## Создать бэкап контента
	@echo "$(GREEN)Создание бэкапа контента...$(NC)"
	@DATE=$(shell date +%Y%m%d_%H%M%S); \
	tar -czf backup_$$DATE.tar.gz content/ static/images/ static/admin/config.yml; \
	echo "$(GREEN)Бэкап создан: backup_$$DATE.tar.gz$(NC)"

# Для продакшена
production-config: ## Переключить CMS на продакшн конфигурацию
	@echo "$(GREEN)Переключение на продакшн конфигурацию CMS...$(NC)"
	@sed -i.bak 's/^backend:/# backend (local):/' static/admin/config.yml
	@sed -i.bak 's/^# backend:/backend:/' static/admin/config.yml
	@sed -i.bak 's/^local_backend: true/# local_backend: true/' static/admin/config.yml
	@echo "$(GREEN)CMS переключен на продакшн режим$(NC)"
	@echo "$(YELLOW)Не забудьте настроить Git Gateway в Netlify$(NC)"

local-config: ## Переключить CMS на локальную конфигурацию
	@echo "$(GREEN)Переключение на локальную конфигурацию CMS...$(NC)"
	@sed -i.bak 's/^backend:/# backend (production):/' static/admin/config.yml
	@sed -i.bak 's/^# backend (local):/backend:/' static/admin/config.yml
	@sed -i.bak 's/^# local_backend: true/local_backend: true/' static/admin/config.yml
	@echo "$(GREEN)CMS переключен на локальный режим$(NC)"

# По умолчанию показываем справку
.DEFAULT_GOAL := help
