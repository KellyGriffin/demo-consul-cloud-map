key:
	@echo "$(shell terraform output private_key)" > key.pem && chmod 0600 key.pem

clean:
	bash delete-cloud-map.sh

open:
	open http://$(shell terraform output shared_services):16686
	open http://$(shell terraform output web):9090/ui
	open http://$(shell terraform output consul_server):8500 