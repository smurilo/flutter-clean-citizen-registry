# Cadastro do Cidadão — Flutter + Clean Architecture

App para **agentes de assistência social** cadastrarem cidadãos em campo, inclusive **sem internet**. O endereço é preenchido automaticamente pelos **webservices públicos ViaCEP e IBGE**, os dados ficam em **SQLite** e uma **fila de sincronização** envia tudo ao servidor quando a conexão volta.

> Segmento: **Setor Público**

## Stack
Flutter 3 / Dart 3 • **Clean Architecture** (feature-first) • **Riverpod** (Notifier, AsyncNotifier, StreamProvider, overrides para DI) • **Dio** (retry com backoff) • **APIs REST públicas reais: ViaCEP e IBGE Localidades** • **sqflite** com migrações versionadas • connectivity_plus • Equatable • mocktail • sqflite_common_ffi • testes de contrato

## Arquitetura

```
lib/
├── core/
│   ├── error/        Failure (sealed) + Result<T>      ← erros como valores
│   ├── network/      Dio + RetryInterceptor, mapeamento de erros, API do governo simulada
│   ├── database/     AppDatabase com migrações v1 → v2
│   └── providers.dart   grafo de dependências (substituível nos testes)
└── features/
    ├── address/
    │   ├── domain/        Address, City, AddressRepository, FindAddressByCep
    │   ├── data/          ViaCepDataSource, IbgeDataSource, AddressCache (SQLite + TTL)
    │   └── presentation/  AddressLookupNotifier, citiesProvider
    └── citizen/
        ├── domain/        Citizen, CitizenValidator, RegisterCitizen, SyncReport
        ├── data/          SQLite (status de sync) + upload idempotente (PUT por id)
        └── presentation/  lista, formulário, RegisterController, SyncController
```
A regra de dependência é respeitada: `domain` não importa Flutter, Dio nem SQLite. `data` implementa as interfaces do domínio, e `presentation` só fala com casos de uso.

### Webservices consumidos
| Serviço | Endpoint | Uso |
|---|---|---|
| **ViaCEP** | `GET /ws/{cep}/json/` | Autopreenche logradouro, bairro, cidade, UF e **código IBGE** |
| **IBGE Localidades** | `GET /api/v1/localidades/estados/{UF}/municipios` | Lista oficial de municípios |
| API de cadastro (simulada) | `PUT /v1/cidadaos/{id}` | Envio idempotente dos cadastros |

### Decisões técnicas
- **Particularidade do ViaCEP tratada**: CEP inexistente volta como HTTP 200 com `{"erro": true}`, e o app converte isso em `NotFoundFailure`.
- **Cache em SQLite com TTL** para CEP e municípios. **Sem rede, usa o cache vencido**: melhor que não responder.
- **Payload do IBGE reduzido** antes de salvar no cache (só `id` e `nome`).
- **Busca de CEP com descarte de respostas antigas**: se o usuário digitar outro CEP, a resposta anterior é ignorada.
- **Offline-first**: o cadastro é salvo localmente na hora. A sincronização roda ao salvar, ao tocar no botão e **quando a conectividade volta**. Registros com falha continuam na fila (até 5 tentativas) sem bloquear os outros.
- **Validação completa no domínio**: nome e sobrenome, CPF com dígito verificador, CPF duplicado, data de nascimento, telefone e número. Todos os erros aparecem de uma vez no formulário.
- **LGPD**: o CPF aparece mascarado na listagem (`529.***.***-25`).

## Como executar
```bash
flutter pub get
flutter run
flutter test                                       # 11 testes (domínio, dados com SQLite real, widget)
flutter test --tags live --run-skipped             # contrato com ViaCEP e IBGE reais
```
